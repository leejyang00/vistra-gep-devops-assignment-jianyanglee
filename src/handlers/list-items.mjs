import { randomUUID } from "node:crypto";
import { logger } from "./utils/logger.mjs";
import { serverError, badRequest, success} from "./utils/response.mjs";

export const handler = async (event) => {
    const requestId = event.requestContext?.requestId ?? randomUUID();
    logger.info("ListItems invoked", { requestId, path: event.path });

    try {
        const params = event.queryStringParameters ?? {};
        const limit = Math.min(parseInt(params.limit, 10) || 20, 100);
        
        if (limit < 1) {
            return badRequest("'limit' must be a positive integer");
        }

        // Stub: In production, scan/query DynamoDB
        // const result = await docClient.send(new ScanCommand({
        //     TableName: TABLE_NAME,
        //     Limit: limit,
        //     ...(params.nextToken && { ExclusiveStartKey: JSON.parse(Buffer.from(params.nextToken, "base64url").toString()) }),
        // }));

        const items = [];
        const responseBody = {
            items,
            count: items.length,
            ...(null && { nextToken: null }), // would encode LastEvaluatedKey
        };

        logger.info("ListItems completed", { requestId, count: items.length });
        return success(responseBody);
    } catch (err) {
        logger.error("ListItems failed", { requestId, error: err.message, stack: err.stack });
        return serverError();
    }

}