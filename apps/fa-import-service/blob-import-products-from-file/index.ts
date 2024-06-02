import { AzureFunction, Context } from "@azure/functions";
import { ServiceBusClient } from "@azure/service-bus";
import { BlobServiceClient } from "@azure/storage-blob";
import { parse } from "csv-parse/sync";

const TOPIC_NAME = "products-import-topic";
const CONNECTION_STRING_STORAGE_ACCOUNT = process.env.AzureWebJobsStorage ?? "";
const CONTAINER_NAME = "my-container";

const blobTrigger: AzureFunction = async function (
  context: Context
): Promise<void> {
  context.log("HTTP blob import products from file processed a request.");

  let blobValue = context.bindings.blob.toString("utf8");
  if (blobValue.charCodeAt(0) === 0xfeff) {
    blobValue = blobValue.substr(1);
  }

  const records: any[] = parse(blobValue, {
    columns: true,
    skip_empty_lines: true,
    delimiter: ",",
    trim: true,
  });

  const messages = records.map((row) => {
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

    return {
      body: product,
      label: "product",
      subject: "product",
    };
  });

  const serviceBusClient = new ServiceBusClient(
    process.env.ServiceBusConnectionString
  );
  const sender = serviceBusClient.createSender(TOPIC_NAME);

  try {
    await sender.sendMessages(messages);

    context.res = {
      status: 200,
      body: "Message sent successfully to Service Bus queue.",
    };
  } catch (error) {
    context.res = {
      status: 500,
      body: `Error sending message to Service Bus: ${error.message}`,
    };
  } finally {
    await sender.close();
    await serviceBusClient.close();
  }

  const [_, blobName] = context.bindingData.blobTrigger.split("/");
  const blobServiceClient = BlobServiceClient.fromConnectionString(
    CONNECTION_STRING_STORAGE_ACCOUNT
  );
  const sourceContainerClient =
    blobServiceClient.getContainerClient(CONTAINER_NAME);
  const sourceBlobClient = sourceContainerClient.getBlobClient(blobName);
  await sourceBlobClient.delete();
};

export default blobTrigger;
