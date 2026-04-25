import { NextFunction, Request, Response } from "express";
import { ZodSchema } from "zod";

export function validateBody<T>(schema: ZodSchema<T>) {
  return (request: Request, _response: Response, next: NextFunction) => {
    request.body = schema.parse(request.body);
    next();
  };
}
