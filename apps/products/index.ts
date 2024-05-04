import { CosmosClient, CosmosClientOptions } from "@azure/cosmos";

const key = process.env.COSMOS_KEY || "";
const endpoint = process.env.COSMOS_ENDPOINT || "";

const DATABASE_NAME = "products-db";
const STOCKS = "stocks";
const PRODUCTS = "products";

const options: CosmosClientOptions = { endpoint, key };
const cosmosClient = new CosmosClient(options);

const database = cosmosClient.database(DATABASE_NAME);

const stockContainer = database.container(STOCKS);
const productsContainer = database.container(PRODUCTS);

productsContainer.items.upsert({
  id: "1",
  title: "PGP1",
  description: "Desc1",
  price: 100,
});

productsContainer.items.upsert({
  id: "2",
  title: "PGP2",
  description: "Desc2",
  price: 150,
});

stockContainer.items.upsert({
  id: "1",
  product_id: "2",
  count: 10,
});
