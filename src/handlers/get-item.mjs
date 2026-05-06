import { logger } from "../utils/logger.mjs";
import { serverError } from "./utils/response.mjs";

export const handler = async (event) => {
    const requestId = event.requestContext?.requestId ?? randomUUID();
    logger.info("GetItem invoked", { requestId, path: event.path });

    try {
        logger.info("Item retrieved", { requestId, itemId: item.id });

    } catch (err) {
        logger.error("GetItem failed", {
            requestId,
            error: err.message,
            stack: err.stack,
        });
        return serverError;
    }
}