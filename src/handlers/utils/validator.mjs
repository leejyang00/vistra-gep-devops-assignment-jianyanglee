
// parse and validate request body
export const parseBody = (event) => {
	if (!event.body) {
		throw new Error("Missing request body");
	}

	try {
		return JSON.parse(event.body);
	} catch {
		throw new Error("Invalid JSON format in request body");
	}
};
