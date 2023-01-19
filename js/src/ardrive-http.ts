// Types
type FetchResponseType = 'text' | 'json' | 'bytes';

type GetProps = [
  url: string,
  responseType: FetchResponseType,
  retries: number,
  retryDelayMs: number,
  noLogs: boolean,
  retryAttempts: number,
];

type PostProps = [
  url: string,
  data: ArrayBuffer | string,
  contentType: string,
  responseType: FetchResponseType,
  retries: number,
  retryDelayMs: number,
  noLogs: boolean,
  retryAttempts: number,
];

type ArDriveHTTPResponse = {
  statusCode: number;
  statusMessage: string;
  data: object | string | BinaryData;
  retryAttempts: number;
};

type ArDriveHTTPException = {
  error: string;
  retryAttempts: number;
};

// Utilities
let retryStatusCodes = [408, 429, 440, 460, 499, 500, 502, 503, 504, 520, 521, 522, 523, 524, 525, 527, 598, 599];

const isStatusCodeError = (code: number): boolean => code >= 400 && code <= 599;

const retryDelay = (attempt: number, retryDelayMs: number): number => retryDelayMs * Math.pow(1.5, attempt);

const logMessage = (url: string, statusCode: number, statusMessage: string, retryAttempts: number): string => {
  return `uri: ${url}
  response: Http status error [${statusCode}]: ${statusMessage}
  retryAttempts: ${retryAttempts}`;
};

const logger = {
  retry: (url: string, statusCode: number, statusMesage: string, retryAttempts: number): void => {
    const standardMessage = logMessage(url, statusCode, statusMesage, retryAttempts);

    console.warn(`Network Request Retry\n${standardMessage}`);
  },
  error: (url: string, statusCode: number, statusMesage: string, retryAttempts: number): void => {
    const standardMessage = logMessage(url, statusCode, statusMesage, retryAttempts);

    console.error(`Network Request Error\n${standardMessage}`);
  },
};

const requestType = {
  json: {
    contentType: 'application/json; charset=utf-8',
    getResponse: async (response: Response) => await response.json(),
  },
  bytes: {
    contentType: 'application/octet-stream',
    getResponse: async (response: Response) => await response.arrayBuffer(),
  },
  text: {
    contentType: 'plain/text; charset=utf-8',
    getResponse: async (response: Response) => await response.text(),
  },
};

const get = async ([url, responseType, retries, retryDelayMs, noLogs = false, retryAttempts = 0]: GetProps): Promise<
  ArDriveHTTPResponse | ArDriveHTTPException
> => {
  try {
    const response = await fetch(url, {
      method: 'GET',
      redirect: 'follow',
      signal: AbortSignal.timeout(8000), // 8s timeout
    });

    const statusCode = response.status;
    const statusMessage = response.statusText;

    if (retries > 0 && retryStatusCodes.includes(statusCode)) {
      if (!noLogs) {
        logger.retry(url, statusCode, statusMessage, retryAttempts);
      }

      return await get([url, responseType, retries - 1, retryDelayMs, noLogs, retryAttempts + 1]);
    } else {
      if (isStatusCodeError(statusCode)) {
        const log = logMessage(url, statusCode, statusMessage, retryAttempts);

        return {
          error: `Network Request Error\n${log}`,
          retryAttempts,
        };
      }
    }

    const data = await requestType[`${responseType}`].getResponse(response);

    return {
      statusCode,
      statusMessage,
      data,
      retryAttempts,
    };
  } catch (error: any) {
    return {
      error: `${error}`,
      retryAttempts,
    };
  }
};

const post = async ([
  url,
  data,
  contentType,
  responseType,
  retries,
  retryDelayMs,
  noLogs = false,
  retryAttempts = 0,
]: PostProps): Promise<ArDriveHTTPResponse | ArDriveHTTPException> => {
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        ...(contentType !== requestType.text.contentType ? { 'Content-Type': contentType } : {}),
      },
      redirect: 'follow',
      body: data,
      signal: AbortSignal.timeout(8000), // 8s timeout
    });

    const statusCode = response.status;
    const statusMessage = response.statusText;

    if (retries > 0 && retryStatusCodes.includes(statusCode)) {
      if (!noLogs) {
        logger.retry(url, statusCode, statusMessage, retryAttempts);
      }

      return await post([url, data, contentType, responseType, retries - 1, retryDelayMs, noLogs, retryAttempts + 1]);
    } else {
      if (isStatusCodeError(statusCode)) {
        const log = logMessage(url, statusCode, statusMessage, retryAttempts);

        return {
          error: `Network Request Error\n${log}`,
          retryAttempts,
        };
      }
    }

    const responseBody = await requestType[`${responseType}`].getResponse(response);

    return {
      statusCode,
      statusMessage,
      data: responseBody,
      retryAttempts,
    };
  } catch (error: any) {
    return {
      error: `${error}`,
      retryAttempts,
    };
  }
};

self.get = get;
self.post = post;
