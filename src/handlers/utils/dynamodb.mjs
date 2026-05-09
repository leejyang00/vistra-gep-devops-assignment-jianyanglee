import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";

export const TABLE_NAME = process.env.TABLE_NAME;

const client = new DynamoDBClient({});
export const docClient = DynamoDBDocumentClient.from(client, {
	marshallOptions: {
		removeUndefinedValues: true,
		convertEmptyValues: false,
	},
	unmarshallOptions: {
		wrapNumbers: false,
	},
});
