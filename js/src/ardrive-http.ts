import axios, { AxiosError } from 'axios';
import axiosRetry from 'axios-retry';

// Utilities
let retryStatusCodes = [408, 429, 440, 460, 499, 500, 502, 503, 504, 520, 521, 522, 523, 524, 525, 527, 598, 599];

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

// Types
type GetProps = [
  url: string,
  responseType: 'text' | 'json' | 'arraybuffer' | 'stream',
  retries: number,
  retryDelayMs: number,
  noLogs: boolean,
];

type PostBytesProps = [url: string, dataBytes: ArrayBuffer, retries: number, retryDelayMs: number, noLogs: boolean];

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

const axiosClient = axios.create();

const get = async ([url, responseType, retries, retryDelayMs, noLogs = false]: GetProps): Promise<
  ArDriveHTTPResponse | ArDriveHTTPException
> => {
  axiosRetry(axiosClient, {
    retries,
    retryDelay: (retryCount: number) => retryDelay(retryCount, retryDelayMs),
    retryCondition: (error: AxiosError) => {
      const status = error.response?.status ?? 0;
      return retryStatusCodes.includes(status);
    },
    onRetry: (count, error) => {
      if (!noLogs) {
        logger.retry(url, error.response?.status || 0, error.response?.statusText || '', count);
      }
    },
  });

  try {
    const response = await axiosClient.get(url, {
      responseType: responseType,
    });

    return {
      statusCode: response.status,
      statusMessage: response.statusText,
      data: response.data,
      retryAttempts: response.config['axios-retry']?.retryCount,
    };
  } catch (error: any) {
    return {
      error: `${error}`,
      retryAttempts: error.response.config['axios-retry'].retryCount,
    };
  }
};

window.get = get;
