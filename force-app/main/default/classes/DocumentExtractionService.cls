public with sharing class DocumentExtractionService {

    // Keep the file size conservative because Base64
    // increases the request body size.
    private static final Integer MAX_FILE_BYTES = 6 * 1024 * 1024;

    public static String extractText(Blob fileData) {

        if (fileData == null || fileData.size() == 0) {
            throw new IllegalArgumentException(
                'PDF file is empty.'
            );
        }

        if (fileData.size() > MAX_FILE_BYTES) {
            throw new IllegalArgumentException(
                'PDF exceeds the supported 6 MB limit.'
            );
        }

        // Convert PDF into Base64
        String base64Pdf =
            EncodingUtil.base64Encode(fileData);

        // Prepare OCR.space request
        HttpRequest request = new HttpRequest();

        request.setEndpoint(
            'callout:Document_OCR_API/parse/image'
        );

        request.setMethod('POST');

        request.setHeader(
            'Content-Type',
            'application/x-www-form-urlencoded'
        );

        // OCR.space accepts Base64 PDF data
        String body =
            'base64Image=' +
            EncodingUtil.urlEncode(
                'data:application/pdf;base64,' + base64Pdf,
                'UTF-8'
            ) +
            '&language=eng' +
            '&isTable=true' +
            '&OCREngine=2';

        request.setBody(body);
        // request.setTimeout(120000);

        // Send request
        Http http = new Http();
        HttpResponse response = http.send(request);

        System.debug('OCR Status: ' +
            response.getStatusCode());

        System.debug('OCR Response: ' +
            response.getBody());

        if (response.getStatusCode() != 200) {
            throw new CalloutException(
                'OCR API failed: ' +
                response.getStatusCode() +
                ' ' + response.getBody()
            );
        }

        // Read JSON response
        Map<String, Object> result =
            (Map<String, Object>)
            JSON.deserializeUntyped(response.getBody());

        // Check OCR processing errors
        Boolean hasError =
            (Boolean) result.get('IsErroredOnProcessing');

        if (hasError == true) {
            throw new CalloutException(
                'OCR processing error: ' +
                String.valueOf(result.get('ErrorMessage'))
            );
        }

        // Extract ParsedResults
        List<Object> parsedResults =
            (List<Object>) result.get('ParsedResults');

        if (parsedResults == null || parsedResults.isEmpty()) {
            throw new CalloutException(
                'OCR response contains no extracted results.'
            );
        }

        Map<String, Object> firstResult =
            (Map<String, Object>) parsedResults[0];

        Object extractedText =
            firstResult.get('ParsedText');

        if (extractedText == null) {
            throw new CalloutException(
                'OCR response does not contain ParsedText.'
            );
        }

        System.debug('Extracted Text: ' + extractedText);

        return String.valueOf(extractedText);
    }
}