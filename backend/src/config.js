export function parsePort(rawPort) {
  if (!/^\d+$/.test(rawPort ?? "")) {
    throw new Error("PORT must be a valid TCP port");
  }

  const port = Number(rawPort);
  if (!Number.isSafeInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be a valid TCP port");
  }
  return port;
}
