import { AzureFunction, Context } from "@azure/functions";
import { parse } from "csv-parse/sync";

const blobTrigger: AzureFunction = async function (
  context: Context
): Promise<void> {
  context.log("HTTP blob import products from file processed a request.");

  const records: any[] = parse(context.bindings.blob, {
    columns: true,
    skip_empty_lines: true,
    delimiter: ",",
    trim: true,
  });

  records
    .map((row) => {
      const product: {
        id?: string;
        title: string;
        description: string;
        count: number;
        price: number;
      } = {
        title: row["title"] || row["Title"] || "",
        description: row["description"] || row["Description"] || "",
        count: +(row["count"] || +row["Count"] || 0),
        price: +(row["price"] || +row["Price"] || 0),
      };
      const id = row["id"] || row["Id"] || row["ID"];
      if (id) {
        product["id"] = id;
      }

      return product;
    })
    .forEach((product) => {
      context.log(
        `PRODUCT: ${product.id || "no ID"}; ${product.title}; ${
          product.description
        }; ${product.count}; ${product.price}`
      );
    });
};

export default blobTrigger;
