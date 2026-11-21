trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert)
 {
    DocumentProcessingHandler.processDocuments(Trigger.new);
 }