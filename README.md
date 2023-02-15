# ArDriveHTTP

ArDriveHTTP is a package to perform network calls for ArDrive Web. It uses Isolates to perform network calls on Dart VM environments and WebWorkers on Web.

### Features

- Standarized network calls
- Support retries
- Use Isolates and WebWorkers to reduce impact on UI process

### Implemented methods

- get()
- getJson()
- getAsBytes()
- getAsByteRangeStream() [via HTTP ranges]

## Getting started

In order to use this package you need to copy `ardrive-http.js` and `workers.js` from `js/dist` folder to your project's `web` folder so they can be dynamic imported when some `ArDriveHTTP` method is called.

## Usage

Simply create a new instance of `ArDriveHTTP` and pass the follow optional params:

- `retries`: amount of retry attempts
- `retryDelayMs`: base retry delay in ms
- `noLogs`: to hide logs

```dart
// Using defaults
final http = ArDriveHTTP()

// Setting params
// Retry 4 times
// Initial delay of 100ms
// Don't log requests
final http = ArDriveHTTP(
  retries: 4,
  retryDelayMs: 100,
  noLog: true,
);
```

Call the intended method like:

```dart
// Get raw response
final response = await ArDriveHTTP().get(url: 'https://url');

// Get JSON response
final jsonResponse = await ArDriveHTTP().get(
  url: 'https://url',
  isJson: true,
);
// OR
final getJsonResponse = await ArDriveHTTP().getJson('https://url');

// Get bytes
final bytesResponse = await ArDriveHTTP().get(
  url: 'https://url',
  asBytes: true,
);
// OR
final getBytesResponse = await ArDriveHTTP().getAsBytes('https://url');
```

## Building

### Typescript

This project uses NodeJS version 18 and Yarn.
All the typescript code used by ArDriveHTTP to run network calls in the browser lives in the `js` folder.

#### Getting dependencies

```sh
yarn
```

#### Building

```sh
yarn build
```

This command will transpile and bundle all typescript code to a minified javascript file called `ardrive-http.js` in `dist` folder.

#### Watching

You can use the following command to automatically rebuild the javascript file whenever a change in the code happens:

```sh
yarn watch
```
