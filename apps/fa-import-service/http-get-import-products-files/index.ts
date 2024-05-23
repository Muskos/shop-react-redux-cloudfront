import { AzureFunction, Context } from "@azure/functions";
import {
  BlobSASPermissions,
  BlobServiceClient,
  generateBlobSASQueryParameters,
  StorageSharedKeyCredential,
} from "@azure/storage-blob";

const CONTAINER_NAME = "my-container";
const CONNECTION_STRING_STORAGE_ACCOUNT = process.env.AzureWebJobsStorage ?? "";
const ACCOUNT_KEY = process.env.ACCOUNT_KEY ?? "";

const httpTrigger: AzureFunction = async function (
  context: Context
): Promise<void> {
  context.log("HTTP get import products file processed a request.");
  const blobName = context.req?.query.name as string;
  const blobServiceClient = BlobServiceClient.fromConnectionString(
    CONNECTION_STRING_STORAGE_ACCOUNT
  );
  const containerClient = blobServiceClient.getContainerClient(CONTAINER_NAME);
  const blobClient = containerClient.getBlobClient(blobName);

  const permissions = BlobSASPermissions.parse("rw");
  const expiryDate = new Date();
  expiryDate.setMinutes(expiryDate.getMinutes() + 15);

  const sharedKeyCredential = new StorageSharedKeyCredential(
    containerClient.accountName,
    ACCOUNT_KEY
  );
  const blobSASSignatureValues = {
    containerName: CONTAINER_NAME,
    blobName,
    permissions,
    startsOn: new Date(),
    expiresOn: expiryDate,
  };

  const sasToken = generateBlobSASQueryParameters(
    blobSASSignatureValues,
    sharedKeyCredential
  ).toString();

  const sasUrl = blobClient.url.split("?")[0] + "?" + sasToken;

  context.res = {
    body: sasUrl,
  };
};

export default httpTrigger;
