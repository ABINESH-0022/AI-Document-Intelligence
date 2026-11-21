public with sharing class DocumentProcessingHandler {

    // Called from the trigger
    public static void processDocuments(List<ContentDocumentLink> fileLinks) {

        List<Id> fileIds = new List<Id>();
        List<Id> recordIds = new List<Id>();

        for (ContentDocumentLink link : fileLinks) {

            if (link.LinkedEntityId != null &&
                link.LinkedEntityId.getSObjectType() ==
                Document_Repository__c.SObjectType) {

                fileIds.add(link.ContentDocumentId);
                recordIds.add(link.LinkedEntityId);
            }
        }

        if (!fileIds.isEmpty()) {
            System.enqueueJob(
                new ProcessingJob(fileIds, recordIds)
            );
        }
    }

    // Compatibility method for existing Queueable class
    public static void processFiles(
        List<Id> fileIds,
        List<Id> recordIds
    ) {
        if (fileIds != null && !fileIds.isEmpty()) {
            System.enqueueJob(
                new ProcessingJob(fileIds, recordIds)
            );
        }
    }

    // Process one PDF document
    public static void processFile(Id contentDocumentId, Id recordId) {

        Document_Repository__c rec =
            new Document_Repository__c(Id = recordId);

        try {

            List<ContentVersion> versions = [
                SELECT Id, FileType, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];

            if (versions.isEmpty() ||
                versions[0].FileType != 'PDF') {

                rec.Processing_Status__c = 'Failed';
                rec.Validation_Status__c = 'Incomplete';
                update rec;
                return;
            }

            // Call OCR.space API
            String extractedText =
                DocumentExtractionService.extractText(
                    versions[0].VersionData
                );

            // Check extracted text
            if (String.isBlank(extractedText)) {

                rec.Processing_Status__c = 'Completed';
                rec.Validation_Status__c = 'Incomplete';

            } else {

                // Store extracted text
                Integer maxLen =
                    Document_Repository__c.Extracted_Content__c
                    .getDescribe().getLength();

                if (extractedText.length() > maxLen) {
                    extractedText =
                        extractedText.substring(0, maxLen);
                }

                rec.Extracted_Content__c = extractedText;

                rec.Processing_Status__c = 'Completed';
                rec.Validation_Status__c = 'Complete';
            }

        } catch (Exception e) {

            System.debug(
                LoggingLevel.ERROR,
                'Document processing failed: ' + e.getMessage()
            );

            rec.Processing_Status__c = 'Failed';
            rec.Validation_Status__c = 'Incomplete';
        }

        update rec;
    }

    // Queueable processing
    public class ProcessingJob
        implements Queueable, Database.AllowsCallouts {

        private List<Id> fileIds;
        private List<Id> recordIds;

        public ProcessingJob(
            List<Id> fileIds,
            List<Id> recordIds
        ) {
            this.fileIds = fileIds;
            this.recordIds = recordIds;
        }

        public void execute(QueueableContext context) {

            if (fileIds == null ||
                recordIds == null ||
                fileIds.isEmpty() ||
                fileIds.size() != recordIds.size()) {
                return;
            }

            try {

                DocumentProcessingHandler.processFile(
                    fileIds[0],
                    recordIds[0]
                );

            } catch (Exception e) {

                System.debug(
                    LoggingLevel.ERROR,
                    'Unexpected processing error: ' + e.getMessage()
                );
            }

            // Process remaining files
            if (fileIds.size() > 1 &&
                !Test.isRunningTest()) {

                List<Id> remainingFiles = new List<Id>();
                List<Id> remainingRecords = new List<Id>();

                for (Integer i = 1; i < fileIds.size(); i++) {

                    remainingFiles.add(fileIds[i]);
                    remainingRecords.add(recordIds[i]);
                }

                System.enqueueJob(
                    new ProcessingJob(
                        remainingFiles,
                        remainingRecords
                    )
                );
            }
        }
    }
}