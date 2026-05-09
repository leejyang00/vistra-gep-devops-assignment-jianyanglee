import { randomUUID } from "node:crypto";
import { logger } from "./utils/logger.mjs";
import { badRequest, notFound, serverError } from "./utils/response.mjs";
// import { docClient, TABLE_NAME } from "./utils/dynamodb.mjs";
// import { DeleteCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async (event) => {
	const requestId = event.requestContext?.requestId ?? randomUUID();
	const itemId = event.pathParameters?.id;

	logger.info("DeleteItem invoked", { requestId, itemId });

	try {
		if (!itemId || itemId.trim().length === 0) {
			return badRequest("Item ID is required");
		}

		// Stub: In production, delete from DynamoDB
		// try {
		//   await docClient.send(new DeleteCommand({
		//     TableName: TABLE_NAME,
		//     Key: { id: itemId },
		//     ConditionExpression: "attribute_exists(id)",
		//   }));
		// } catch (err) {
		//   if (err.name === "ConditionalCheckFailedException") {
		//     return notFound(`Item '${itemId}' not found`);
		//   }
		//   throw err;
		// }

		// Simulate not-found for demonstration
		logger.warn("Item not found (stub)", { requestId, itemId });
		return notFound(`Item '${itemId}' not found`);
	} catch (err) {
		logger.error("DeleteItem failed", {
			requestId,
			itemId,
			error: err.message,
			stack: err.stack,
		});
		return serverError();
	}
};
