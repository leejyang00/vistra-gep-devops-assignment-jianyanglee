import { randomUUID } from "node:crypto";
import { PutCommand } from "@aws-sdk/lib-dynamodb";
import { docClient, TABLE_NAME } from "./utils/dynamodb.mjs";
import { logger } from "./utils/logger.mjs";
import { badRequest, created, serverError } from "./utils/response.mjs";
import {
	parseBody,
	validateItemInput,
	validateRequiredFields,
} from "./utils/validator.mjs";

export const handler = async (event) => {
	const requestId = event.requestContext?.requestId ?? randomUUID();
	logger.info("CreateItem invoked", { requestId, path: event.path });

	try {
		const body = parseBody(event);
		if (!body) {
			logger.warn("Invalid JSON body", { requestId });
			return badRequest("Request body must be a valid JSON");
		}

		// validation
		const requiredErrors = validateRequiredFields(body, ["name", "status"]);
		const validationErrors = validateItemInput(body);
		const allErrors = [...requiredErrors, ...validationErrors];

		if (allErrors.length > 0) {
			logger.warn("Validation failed", { requestId, errors: allErrors });
			return badRequest("Validation failed", allErrors);
		}

		const now = new Date().toISOString();
		const item = {
			id: randomUUID(),
			name: body.name.trim(),
			description: body.description,
			status: body.status ?? "active",
			createdAt: now,
			updatedAt: now,
		};

		// persist item to DynamoDB
		await docClient.send(
			new PutCommand({
				TableName: TABLE_NAME,
				Item: item,
				ConditionExpression: "attribute_not_exists(id)", // Ensure no duplicate IDs
			}),
		);

		logger.info("Item created", { requestId, itemId: item.id });
		return created(item);
	} catch (err) {
		logger.error("CreateItem failed", {
			requestId,
			error: err.message,
			stack: err.stack,
		});
		return serverError;
	}
};
