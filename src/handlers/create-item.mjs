import { logger } from "../utils/logger.mjs";
import { parseBody } from "../utils/parse-body.mjs";
import { badRequest, created, serverError } from "./utils/response.mjs";

export const handler = async (event) => {
	const requestId = event.requestContext?.requestId ?? randomUUID();
	logger.info("CreateItem invoked", { requestId, path: event.path });

	try {
		const body = parseBody(event);
		if (!body) {
			logger.warn("Invalid JSON body", { requestId });
			return badRequest("Request body must be a valid JSON");
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

		// TODO: persist item to database (e.g., DynamoDB)

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
