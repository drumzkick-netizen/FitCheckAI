/**
 * Typed errors for /analyze-photo so the route can return appropriate status and client-safe codes.
 * Do not attach secrets or raw API payloads to these errors.
 */

export class OpenAIServiceError extends Error {
  override name = "OpenAIServiceError" as const;
  constructor(
    message: string,
    public readonly statusCode?: number
  ) {
    super(message);
    Object.setPrototypeOf(this, OpenAIServiceError.prototype);
  }
}

export class InvalidAIResponseError extends Error {
  override name = "InvalidAIResponseError" as const;
  constructor(message: string = "Invalid AI response format") {
    super(message);
    Object.setPrototypeOf(this, InvalidAIResponseError.prototype);
  }
}
