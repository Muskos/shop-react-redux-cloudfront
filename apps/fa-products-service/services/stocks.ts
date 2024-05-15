import cosmosClient from "./cosmosDb";

const stocksContainer = cosmosClient
  .database("products-db")
  .container("stocks");

export const getStock = async (id) => {
  const stock = await stocksContainer.items
    .query(`SELECT * FROM s WHERE s.product_id = "${id}"`)
    .fetchAll();

  return stock.resources[0];
};

export const createStock = async (id, count) => {
  const stock = await getStock(id);
  const newStock: {
    product_id: string;
    count: number;
    id?: string;
  } = {
    product_id: id,
    count,
  };

  if (stock) {
    newStock.id = stock.id;
  }

  return stocksContainer.items.upsert(newStock);
};
