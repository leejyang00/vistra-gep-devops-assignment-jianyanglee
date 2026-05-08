import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { logger } from "./utils/logger.mjs";
import { randomUUID } from "node:crypto";
import { serverError, badRequest, notFound, success} from "./utils/response.mjs";
import { TABLE_NAME, docClient } from "./utils/dynamodb.mjs";

export const handler = async (event) => {
    const requestId = event.requestContext?.requestId ?? randomUUID();
    const itemId = event.pathParameters?.id;

    logger.info("GetItem invoked", { requestId, path: event.path });

    try {
        if (!itemId || itemId.trim().length === 0) {
        return badRequest("Item ID is required");
        }

        // dynamodb query 
        const result = await docClient.send(new GetCommand({
            TableName: TABLE_NAME,
            Key: { id: itemId },
        }));
        if (!result.Item) {
            logger.warn("Item not found", { requestId, itemId });
            return notFound(`Item '${itemId}' not found`);
        }

        logger.info("Item retrieved", { requestId, itemId });
        return success(result.Item);
    } catch (err) {
        logger.error("GetItem failed", { requestId, itemId, error: err.message, stack: err.stack });
        return serverError();
    }
}