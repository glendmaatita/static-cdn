local aws_signature = require("resty.aws_signature")
local cjson = require("cjson")
local http = require("resty.http")
local str = require("resty.string")
local io = require("io")
local ngx_re = require("ngx.re")

-- S3 credentials
local access_key = os.getenv("AWS_ACCESS_KEY_ID")
local secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")

-- Local file storage path
local storage_dir = "/tmp/s3_uploads/"

local function get_target_url()
    local request_uri = ngx.var.request_uri
    ngx.log(ngx.ERR, "Request URI: " .. request_uri)
    request_uri = string.gsub(request_uri, " ", "%%20")

    -- Decode percent-encoded characters (e.g., "https%3A" -> "https:")
    local decoded_uri = ngx.unescape_uri(request_uri)
    ngx.log(ngx.ERR, "Decoded URI: " .. decoded_uri)

    -- Fix duplicate "/upload/https://" occurrences
    local normalized_uri = decoded_uri:gsub("^/upload/(https?://[^/]+/upload/)", "/upload/")
    ngx.log(ngx.ERR, "Normalized URI: " .. normalized_uri)

    -- Regex pattern to correctly extract endpoint, bucket, and filename
    local pattern = [[^/upload/(https?://([^/]+)/([^/]+)/(.*))$]]

    -- Match URI
    local matches, err = ngx.re.match(normalized_uri, pattern, "jo")

    if not matches then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.log(ngx.ERR, "Invalid request URI format: " .. normalized_uri)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    -- Extract values
    local endpoint = matches[2]  -- Second capture group (endpoint)
    local bucket = matches[3]    -- Third capture group (bucket)
    local filename = matches[4]  -- Fourth capture group (filename)

    -- Extract region from endpoint
    local region = endpoint:match("^([^.]+)")
    if not region then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.log(ngx.ERR, "Invalid endpoint format: " .. endpoint)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    ngx.log(ngx.ERR, "Extracted values -> Endpoint: " .. endpoint .. ", Bucket: " .. bucket .. ", Filename: " .. filename .. ", Region: " .. region)

    return endpoint, bucket, filename, region
end


-- Save file locally
local function save_file_to_disk(filename, data)
    local full_path = storage_dir .. filename
    local dir_path = full_path:match("(.*/)")  -- Extract directory path

    -- Create directories if they don't exist
    if dir_path then
        os.execute("mkdir -p " .. dir_path)
    end

    local file = io.open(full_path, "wb")
    if not file then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.log(ngx.ERR, "Failed to save file locally: " .. full_path)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    file:write(data)
    file:close()
    return full_path
end


-- Upload the file to S3
local function upload_to_s3(file_path, endpoint, bucket, filename, region)
    -- Get the current time in UTC format
    local date_iso8601 = os.date("!%Y%m%dT%H%M%SZ")
    local date_stamp = os.date("!%Y%m%d")  -- Only the date part

    -- Prepare the S3 request path (bucket and filename)
    local uri = "/" .. filename

    -- Create headers
    local headers = {
        ["Host"] = bucket .. "." .. endpoint
    }

    -- Compute the SHA-256 hash of the file data
    local file = io.open(file_path, "rb")
    local file_data = file:read("*all")
    file:close()

    -- Prepare the signing options for AWS Signature V4
    local opts = {
        method = "PUT",
        uri = uri,
        service = "s3",
        region = region,
        headers = headers,
        access_key = access_key,
        secret_key = secret_key,
        date_iso8601 = date_iso8601,
        date_stamp = date_stamp,
        payload = file_data,
    }

    -- Sign the request using AWS Signature V4
    local signed_request = aws_signature.sign_request(opts)

    if not signed_request then
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.log(ngx.ERR, "Invalid signature")
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    -- Make the HTTP PUT request to upload the file to S3
    local httpc = http.new()
    local res, err = httpc:request_uri("https://" .. bucket .. "." .. endpoint .. uri, {
        method = "PUT",
        headers = signed_request.headers,
        body = file_data,
        ssl_verify = false,  -- Adjust as needed
    })

    -- Check for errors or success
    if not res then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.log(ngx.ERR, "Failed to upload file to S3: " .. err)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if res.status == 200 then
        ngx.status = ngx.HTTP_OK
        ngx.log(ngx.ERR, "File uploaded successfully to S3")
    else
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.log(ngx.ERR, "Failed to upload file to S3: " .. res.body)
    end
end

-- Handle incoming request and extract the file
ngx.req.read_body()
local body = ngx.req.get_body_data()
local headers = ngx.req.get_headers()

if not body then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.log(ngx.ERR, "No file data received")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- Extract endpoint, bucket, filename, and region from the request URI
local endpoint, bucket, filename, region = get_target_url()
if not endpoint or not bucket or not filename or not region then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.log(ngx.ERR, "Invalid request format")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- Save the file locally
local file_path = save_file_to_disk(filename, body)

-- Upload the file to S3
upload_to_s3(file_path, endpoint, bucket, filename, region)