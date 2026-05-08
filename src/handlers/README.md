

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
    "requestContext": {"requestId": "test-394qwe"},
    "body": "{\"name\":\"jian-4\",\"description\":\"bob is a friend \",\"status\":\"inactive\"}"
  }' \
  response.json && cat response.json

aws lambda invoke \
  --function-name vistra-serverless-api-dev-get-item \
  --region ap-southeast-2 \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "path": "/items/8c9dd9d5-268e-4095-b8f0-0ad53ecd3528",
    "httpMethod": "GET",
    "pathParameters": {"id": "8c9dd9d5-268e-4095-b8f0-0ad53ecd3528"},
    "headers": {"Content-Type": "application/json"},
    "requestContext": {}
  }' \
  response.json && cat response.json

```