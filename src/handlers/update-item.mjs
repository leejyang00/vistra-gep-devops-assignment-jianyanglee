import { randomUUID } from "node:crypto";
import { logger } from "./utils/logger.mjs";
import { badRequest, notFound, serverError } from "./utils/response.mjs";
import { parseBody, validateItemInput } from "./utils/validator.mjs";
// import { docClient, TABLE_NAME } from "./lib/dynamodb.mjs";
// import { UpdateCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async (event) => {
	const requestId = event.requestContext?.requestId ?? randomUUID();
	const itemId = event.pathParameters?.id;

	logger.info("UpdateItem invoked", { requestId, itemId });

	try {
		if (!itemId || itemId.trim().length === 0) {
			return badRequest("Item ID is required");
		}

		const body = parseBody(event);
		if (!body) {
			logger.warn("Invalid JSON body", { requestId });
			return badRequest("Request body must be valid JSON");
		}

		const validationErrors = validateItemInput(body);
		if (validationErrors.length > 0) {
			logger.warn("Validation failed", { requestId, errors: validationErrors });
			return badRequest("Validation failed", validationErrors);
		}

		// Ensure at least one updatable field is provided
		const updatableFields = ["name", "description", "status"];
		const hasUpdate = updatableFields.some(
			(field) => body[field] !== undefined,
		);
		if (!hasUpdate) {
			return badRequest(
				"At least one field must be provided for update",
				updatableFields,
			);
		}

		// Stub: In production, update in DynamoDB
		// const updateExpressions = [];
		// const expressionValues = {};
		// const expressionNames = {};
		//
		// if (body.name !== undefined) {
		//   updateExpressions.push("#n = :name");
		//   expressionNames["#n"] = "name";
		//   expressionValues[":name"] = body.name.trim();
		// }
		// ...
		//
		// const result = await docClient.send(new UpdateCommand({
		//   TableName: TABLE_NAME,
		//   Key: { id: itemId },
		//   UpdateExpression: `SET ${updateExpressions.join(", ")}, updatedAt = :now`,
		//   ExpressionAttributeValues: { ...expressionValues, ":now": new Date().toISOString() },
		//   ExpressionAttributeNames: expressionNames,
		//   ConditionExpression: "attribute_exists(id)",
		//   ReturnValues: "ALL_NEW",
		// }));

		// Simulate not-found for demonstration
		logger.warn("Item not found (stub)", { requestId, itemId });
		return notFound(`Item '${itemId}' not found`);
	} catch (err) {
		logger.error("UpdateItem failed", {
			requestId,
			itemId,
			error: err.message,
			stack: err.stack,
		});
		return serverError();
	}
};
