import cosmosClient from "./cosmosDb";
import { getStock, createStock } from "./stocks";

const SELECT_PRODUCTS = "SELECT * FROM products";
const productsContainer = cosmosClient
  .database("products-db")
  .container("products");

export const getProducts = async () => {
  const products = await productsContainer.items
    .query(SELECT_PRODUCTS)
    .fetchAll();

  return Promise.all(
    products.resources.map(async (product) => {
      const stock = await getStock(product.id);

      return {
        ...product,
        count: stock ? stock.count || 1 : 0,
      };
    })
  );
};

export const getProduct = async (id) => {
  const product = await productsContainer.item(id, id).read();
  const stock = await getStock(product.resource.id);

  return {
    ...product.resource,
    count: stock ? stock.count || 1 : 0,
  };
};

export const createProduct = async (product) => {
  const updatedProduct: {
    title: string;
    description: string;
    price: string;
    id?: string;
  } = {
    title: product.title,
    description: product.description,
    price: product.price,
  };
  if (product.id) {
    updatedProduct.id = product.id;
  }
  const { resource: newProduct } = await productsContainer.items.upsert(
    updatedProduct
  );

  const { resource: newStock } = await createStock(
    newProduct.id,
    product.count
  );

  return {
    ...product,
    id: newProduct.id,
    count: newStock.count,
  };
};

export const getProductTotal = async () => {
  const products = await getProducts();

  return products.reduce((acc, item) => {
    return acc + item.count;
  }, 0);
};
