import { CosmosClient, CosmosClientOptions } from "@azure/cosmos";

const key = process.env.COSMOS_KEY || "";
const endpoint = process.env.COSMOS_ENDPOINT || "";

const options: CosmosClientOptions = { endpoint, key };
const cosmosClient = new CosmosClient(options);

export default cosmosClient;
