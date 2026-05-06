/**
 * Structured JSON Logger
 *
 * Produces structured log lines consumable by CloudWatch Insights.
 * Each log entry includes timestamp, level, message, and optional context.
 * Log level is controlled via the LOG_LEVEL environment variable.
 */

const LOG_LEVELS = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };
const currentLevel =
	LOG_LEVELS[process.env.LOG_LEVEL ?? "INFO"] ?? LOG_LEVELS.INFO;

const formatEntry = (level, message, context = {}) =>
	JSON.stringify({
		timestamp: new Date().toISOString(),
		level,
		message,
		...context,
	});

export const logger = {
	debug: (message, context) => {
		if (currentLevel <= LOG_LEVELS.DEBUG) {
			console.debug(formatEntry("DEBUG", message, context));
		}
	},
	info: (message, context) => {
		if (currentLevel <= LOG_LEVELS.INFO) {
			console.info(formatEntry("INFO", message, context));
		}
	},
	warn: (message, context) => {
		if (currentLevel <= LOG_LEVELS.WARN) {
			console.warn(formatEntry("WARN", message, context));
		}
	},
	error: (message, context) => {
		if (currentLevel <= LOG_LEVELS.ERROR) {
			console.error(formatEntry("ERROR", message, context));
		}
	},
};
