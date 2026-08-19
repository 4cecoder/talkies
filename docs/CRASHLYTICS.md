# Crash Reporting API

## Overview

The application sends crash reports to a configurable HTTPS endpoint when crashes occur. This allows for centralized crash logging and monitoring.

## Endpoint Configuration

Set the `CrashReportingEndpoint` in the application settings to a valid HTTPS URL that can receive POST requests.

## API Endpoint

- **URL**: Configurable via `CrashReportingEndpoint` setting
- **Method**: POST
- **Headers**:
  - `Content-Type: application/json`
- **Body**: JSON object containing crash details

## Request Format

The POST request body contains a JSON object with the following structure:

```json
{
  "Timestamp": "string (ISO 8601 format)",
  "PcName": "string",
  "Ip": "string",
  "Exception": "string (full exception details)",
  "IsTerminating": "boolean",
  "Platform": "string",
  "Version": "string",
  "FullLogDump": "string"
}
```

### Example Request

```json
POST /crash-reports HTTP/1.1
Host: your-endpoint.com
Content-Type: application/json
Content-Length: 1234

{
  "Timestamp": "2025-12-19T06:30:17.9914525Z",
  "PcName": "USER-PC",
  "Ip": "192.168.1.100",
  "Exception": "System.InvalidOperationException: An error occurred.\n   at MyApp.Main()",
  "IsTerminating": true,
  "Platform": "windows",
  "Version": "1.0.0.0",
  "FullLogDump": "Previous crash logs..."
}
```

## Endpoint Implementation

Your endpoint should:

1. Accept POST requests with `Content-Type: application/json`
2. Parse the JSON body
3. Log or store the crash data for analysis
4. Return a success response (2xx status code)

## Security Considerations

- Only accept requests from trusted sources
- Use HTTPS to encrypt crash data in transit
- Validate the JSON structure before processing
- Implement rate limiting to prevent abuse

## Response

The endpoint should return:

- **Success**: HTTP 200 OK or similar 2xx status
- **Failure**: Appropriate error status (400, 500, etc.)

The application logs success or failure based on the HTTP response status.