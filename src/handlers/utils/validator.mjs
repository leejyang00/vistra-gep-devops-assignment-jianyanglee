/**
 * Input Validation
 *
 * Lightweight validation for item request bodies. Returns an array
 * of error strings — empty means valid.
 */

const MAX_NAME_LENGTH = 255;
const MAX_DESCRIPTION_LENGTH = 1024;

export const validateItemInput = (body) => {
	const errors = [];

	if (!body || typeof body !== "object") {
		return ["Request body must be a JSON object"];
	}

	if (body.name !== undefined) {
		if (typeof body.name !== "string" || body.name.trim().length === 0) {
			errors.push("'name' must be a non-empty string");
		} else if (body.name.length > MAX_NAME_LENGTH) {
			errors.push(`'name' must not exceed ${MAX_NAME_LENGTH} characters`);
		}
	}

	if (body.description !== undefined) {
		if (typeof body.description !== "string") {
			errors.push("'description' must be a string");
		} else if (body.description.length > MAX_DESCRIPTION_LENGTH) {
			errors.push(
				`'description' must not exceed ${MAX_DESCRIPTION_LENGTH} characters`,
			);
		}
	}

	if (body.status !== undefined) {
		const validStatuses = ["active", "inactive", "archived"];
		if (!validStatuses.includes(body.status)) {
			errors.push(`'status' must be one of: ${validStatuses.join(", ")}`);
		}
	}

	return errors;
};

export const validateRequiredFields = (body, requiredFields) => {
	const errors = [];
	for (const field of requiredFields) {
		if (body[field] === undefined || body[field] === null) {
			errors.push(`'${field}' is required`);
		}
	}
	return errors;
};

// parse JSON body safely, returning null if invalid
export const parseBody = (event) => {
	if (!event.body) return null;
	try {
		return JSON.parse(event.body);
	} catch {
		return null;
	}
};
