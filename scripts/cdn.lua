local http = require("resty.http")
local sha256 = require("resty.sha256")
local str = require("resty.string")

local function get_file_extension(url)
    local clean_url = url:match("([^?]+)")
    return clean_url:match("%.([a-zA-Z0-9]+)$") or "bin"
end

local function hash_url(url)
    local sha = sha256:new()
    sha:update(url)
    return str.to_hex(sha:final())
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function download_file(url, save_path)
    ngx.log(ngx.ERR, "Downloaded: ", url, " ", save_path)
    local httpc = http.new()
    local res, err = httpc:request_uri(url, { method = "GET", ssl_verify = false })

    ngx.log(ngx.ERR, "Downloaded: ", url, " ", save_path)

    if not res then
        ngx.log(ngx.ERR, "Failed to download: ", err)
        return false
    end

    local file = io.open(save_path, "wb")
    if file then
        file:write(res.body)
        file:close()
        return true
    end
    return false
end

local request_uri = ngx.var.request_uri
local remote_url = request_uri:match("^/serve/(.+)$")

if not remote_url then
    ngx.status = 400
    ngx.say("Invalid request format")
    return
end

-- Download file if not exists
remote_url = ngx.unescape_uri(remote_url)

local hash = hash_url(remote_url)
local ext = get_file_extension(remote_url)

local filename = hash .. "." .. ext
local file_path = "/opt/data/static/" .. filename

if not file_exists(file_path) then
    if not download_file(remote_url, file_path) then
        ngx.status = 502
        ngx.say("Failed to fetch file")
        return
    end
end

if ext == "pdf" then
    ngx.header["Content-Type"] = "application/pdf"
    ngx.header["Content-Disposition"] = "inline"
else
    ngx.header["Content-Type"] = "application/octet-stream"
end

-- Serve static files
ngx.exec("/static/" .. filename)