public class DocumentProcessingQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> fileIds;
    private List<Id> recordIds;

    public DocumentProcessingQueueable(List<Id> fileIds, List<Id> recordIds) {
        this.fileIds = fileIds;
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
        if (fileIds == null || fileIds.isEmpty()) {
            return;
        }

        try {
            DocumentProcessingHandler.processFile(fileIds[0], recordIds[0]);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Unexpected error processing ' + recordIds[0] + ': ' + e.getMessage());
        }

        if (fileIds.size() > 1 && !Test.isRunningTest()) {
            List<Id> remainingFiles = new List<Id>();
            List<Id> remainingRecords = new List<Id>();
            for (Integer i = 1; i < fileIds.size(); i++) {
                remainingFiles.add(fileIds[i]);
                remainingRecords.add(recordIds[i]);
            }
            System.enqueueJob(
                new DocumentProcessingQueueable(remainingFiles, remainingRecords)
            );
        }
    }
}