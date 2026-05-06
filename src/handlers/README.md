

formatting
```
npx biome check --write .   # format + sort imports + lint fixes
npx biome format --write .  # format only
```

```
# sample invoke
aws lambda invoke \
  --function-name vistra-serverless-api-dev-create-item \
  --region ap-southeast-2 \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "path": "/items",
    "httpMethod": "POST",
    "headers": {"Content-Type": "application/json"},
    "requestContext": {"requestId": "test-123"},
    "body": "{\"name\":\"why did you do\",\"description\":\"Invoked from batman\",\"status\":\"deny\"}"
  }' \
  response.json && cat response.json

```