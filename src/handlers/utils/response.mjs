const CORS_HEADERS = {
	"Access-Control-Allow-Origin": "*",
	"Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
	"Access-Control-Allow-Headers":
		"Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
	"Content-Type": "application/json",
};

// response helper functions
export const response = (statusCode, body) => ({
	statusCode,
	headers: CORS_HEADERS,
	body: JSON.stringify(body),
});

// success response helper
export const success = (data, statusCode = 200) =>
	response(statusCode, { success: true, data });

// error response helper
export const error = (statusCode, message, details = undefined) =>
	response(statusCode, {
		success: false,
		error: { message, ...(details && { details }) },
	});

// specific response helpers
export const created = (data) => success(data, 201);
export const badRequest = (message, details) => error(400, message, details);
export const notFound = (message = "Resource not found") => error(404, message);
export const serverError = (message = "Internal server error") =>
	error(500, message);
