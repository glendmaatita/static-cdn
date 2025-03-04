local http = require("resty.http")

-- format upload http://proxy-url.com/upload/http://target-url.com
local function get_target_url()
    local uri = ngx.var.request_uri
    local target_url = uri:match("^/upload/(.+)$")

    if not target_url then
        return nil
    end

    target_url = ngx.unescape_uri(target_url)

    -- Support http or https
    if not target_url:find("^https?://") then
        return nil
    end

    return target_url
end

local function forward_request(target_url)
    local httpc = http.new()

    ngx.req.read_body()
    local body = ngx.req.get_body_data()

    local res, err = httpc:request_uri(target_url, {
        method = ngx.req.get_method(),
        body = body,
        headers = ngx.req.get_headers(),
        ssl_verify = false, -- support http/https target url
        keepalive = false
    })

    if not res then
        ngx.status = 502
        ngx.say("Error: Cannot reach " .. target_url .. " - " .. (err or "unknown error"))
        return
    end

    ngx.status = res.status
    for k, v in pairs(res.headers) do
        ngx.header[k] = v
    end
    ngx.print(res.body)
end

local target_url = get_target_url()
if not target_url then
    ngx.status = 400
    ngx.say("Error: Invalid or missing target URL")
    return
end

forward_request(target_url)
