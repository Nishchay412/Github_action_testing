/***************************************************************************************
Class Name : ActivityTimelineSearchRedesign
Created Date : 07-04-2025
Test Class : ActivityTimelineSearchRedesignTest
Description : 
 
Modification Log:

* Developer Name    Date        Description
-----------------------------------------------------------------------------------------
* Prathyusha KV     07-04-2025  WMCSFH2-5828 
* Prathyusha KV     02-05-2025  WMCSFH2-6120,WMCSFH2-6059,WMCSFH2-5893 
* Nicole Fernandez  26-05-2025  WMCSFH2-6146
* Prathyusha KV     02-06-2025  WMCSFH2-6041,6014 changes to add marketing email filters and description for action plan and email
* Prathyusha KV     30-06-2025  WMCSFH2-6593 Changes for recurring Tasks
* Sandhya Shree     07-07-2025  WMCSFH2-6672 modal for recurring task icon
* Lily Wu           26-06-2025  WMCSFH2-5817 Pinned Activities Redesign - Profile Panel
* Prathyusha KV     09-07-2025  WMCSFH2-6622,6624 Filter for Call and document
* Nicole Fernandez  25-07-2025  WMCSFH2-6684 Display Logic for Recurring Tasks on Profile Panel - Upcoming Child Task
* Sandhya Shree     25-07-2025  WMCSFH2-6384 Refresh Button (Icon) for "Recent Activities" screen
* Nicole Fernandez  07-08-2025  WMCSFH2-7013 PPR: Populating the "For" column on child task in recurring task modal
* Prathyusha KV     25-08-2025  WMCSFH2-6404 "Note" Checkbox Logic
* Sandhya Shree     04-09-2025  WMCSFH2-7220 PPR: Populating the "For" column correctly for child 
* Pavani Malla      04-09-2025  WMCSFH2-7207 Added subtype to display the subtype of task/document
* Sandhya Shree     08-09-2025  WMCSFH2-7119 Display Parent Record in Recurring Task Modal
* Lily Wu           11-09-2025  WMCSFH2-7282 Enhance Searching Logic in Recent Activities to Include Child Records for Recurring Tasks
******************************************************************************************/

public with sharing class ActivityTimelineSearchRedesign {
    
    public static final String CLASS_NAME = 'ActivityTimelineSearchRedesign';
    public static final String COLUMN_TYPE = 'text';
    public static final Boolean COLUMN_SORTABLE = true;

    /*
     * This method is called from the UI/LWC, which sends search parameters to search for activities associde with the profile record.
     * 
     * @param   recordId - Record ID of the related data object
     * @param   checkBoxType - contains the list of filter options as selected on the UI
     * @param   searchTerm - the string entered by the user on the UI
     * @param   pastActivitiesFilter - value as selected by user on the user on past date range (i.e. past 3 months)
     * @param   dateType - as selected by user on the UI to define the type of date to be used on the start/end date range
     * @param   startDate - start date range as selected by user on the UI
     * @param   endDate - start date range as selected by user on the UI
     * @param   createdBy - the user id as entered by the user for the search
     * @param   assignedTo - the user id as entered by the user for the search
     */  
   
    @AuraEnabled()
    public static ActivitySearchResults getActivityResults(Id recordId, List<String> checkBoxType, String searchTerm, 
                                                           String pastActivitiesFilter, String dateType, String startDate, 
                                                           String endDate, String createdBy, String assignedTo,Integer rows,
                                                           Integer offset,string sortBy, string sortDirection)
    {
        ActivitySearchResults results = new ActivitySearchResults('Account');
        try {
            system.debug('*** ActivityTimelineSearchRedesign.getActivityResults() -- START ***');
            List<ActivityCustomDataRowWrapper> listRecords = new List<ActivityCustomDataRowWrapper>();
            
            List<String> columnApiNames = new List<String>();
            
            List<DataTable.DataTableColumn> dataTableColumns = new List<DataTable.DataTableColumn>();
            DataTable dataTable = new DataTable();
            
            results.isGreaterThan2k = false;
            String objectLabelName = 'Account';
            
            // Set up the columns
            Map<String,String> columnMap = new Map<String,String>();
            columnMap.put('Subject', 'Subject');
            columnMap.put('Status', 'Status');
            columnMap.put('Last Modified', 'Last Modified');
            columnMap.put('Assigned To', 'Assigned To');
            columnMap.put('Due Date', 'Due Date');
            columnMap.put('Priority', 'Priority');
            columnMap.put('Type', 'Type');
            columnMap.put('Description', 'Description');
            columnMap.put('Is Pinned', 'Is Pinned');
            
            if(!columnMap.isEmpty()){
                for(String columnApiName:columnMap.keyset()){
                    DataTable.DataTableColumn column = new DataTable.DataTableColumn(columnMap.get(columnApiName), columnApiName, 
                                                                                     COLUMN_TYPE, COLUMN_SORTABLE);
                    dataTableColumns.add(column);
                    columnApiNames.add(columnApiName);
                }
                dataTable.columns = dataTableColumns;
            }
            system.debug('checkboxtypessss1---->'+checkBoxType);
            
            system.debug('Calling searchActivityRecords() method ... ');
            listRecords = searchActivityRecords(recordId, checkBoxType, searchTerm, pastActivitiesFilter, dateType, startDate, endDate,
                                                createdBy,assignedTo,rows,offset,sortBy,sortDirection);
            dataTable.activityRecords = listRecords;
            dataTable.objectApiName = 'Account';
            
            results.dataTableResponse = dataTable;
            results.pageSizeOptions = '10,50,100';
            results.isHousehold = ActivitytimelineUtility.checkIsHousehold(recordId);
            return results;
        }
        catch(Exception e) {
            ExceptionHandler.createErrorLogRecords(e,ConstantsActivityTimeline.CUSTOM_ACTIVITY_TIMELINE,'getActivityResults', NULL);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /*
     * Returns list of recurring task for the parent task
     */
    @AuraEnabled
    public static List<Task> getRecurringTask(Id taskId) 
    {
        try {
           return [
                SELECT Id, IsRecurrence, Subject, toLabel(Status), ActivityDate, Owner.Name, RecurrenceActivityId, Description, Who.Name, What.Name
                FROM Task 
                WHERE RecurrenceActivityId =: taskId
                AND IsRecurrence = FALSE
                AND Status !=: Label.Task_Status_Completed
                ORDER BY ActivityDate ASC
            ];
        }
        catch(Exception e) {
            ExceptionHandler.createErrorLogRecords(e,ConstantsActivityTimeline.CUSTOM_ACTIVITY_TIMELINE,'getRecurringTask', NULL);
            throw new AuraHandledException(e.getMessage());
        }
    } 
    
    /*
     * Returns parent task for the modal
     */
    @AuraEnabled
    public static List<Task> getParentTask(Id taskId) 
    {
        try {
            return [
                SELECT Id, IsRecurrence, Subject, toLabel(Status), ActivityDate, Owner.Name, RecurrenceActivityId, Description, Who.Name, What.Name, CreatedDate
                FROM Task 
                WHERE Id =: taskId
                AND IsRecurrence = TRUE
                ORDER BY ActivityDate ASC
            ];
        }
        catch(Exception e) {
            ExceptionHandler.createErrorLogRecords(e,ConstantsActivityTimeline.CUSTOM_ACTIVITY_TIMELINE,'getParentTask', NULL);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /*
     * Returns Activity records as a list of ActivityCustomDataRowWrapper objects to be used in UI.  This
     * method utlilizes the ActivityTimelineUtility class, which contains logic to query for child activities.
     */ 
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> searchActivityRecords(Id recordId, List <String> checkBoxType, String searchTerm,
                                                                           String pastActivities, String dateType, String startDate, 
                                                                           String enddate, String createdBy, String assignedTo,Integer rows,
                                                                           Integer offset, String sortBy, String sortDirection)
    {        
        system.debug('*** ActivityTimelineSearchRedesign.searchActivityRecords() -- START ***');
        system.debug('--> checkBoxType'+checkBoxType);
        system.debug('--> searchTerm = '+searchTerm);
        system.debug('--> pastActivities='+pastActivities);
        system.debug('--> dateType='+dateType);
        system.debug('--> startDate='+startDate);
        system.debug('--> sortBy='+sortBy);
        system.debug('--> offset='+offset);
        system.debug('--> sortDirection='+sortDirection);
        system.debug('--> rows='+rows);


        Boolean isAsc = sortDirection != null && sortDirection.equalsIgnoreCase('asc') ? true : false;
        Set<String> setType = new Set<String> ();
        if (checkBoxType != NULL && checkBoxType.size() > 0) { 
            setType.addAll(checkBoxType);
        } else {
            setType.add(ConstantsActivityTimeline.SET_TYPE_TASK);
            setType.add(ConstantsActivityTimeline.SET_TYPE_EVENT);
            setType.add(ConstantsActivityTimeline.SET_TYPE_DOCUMENT);
            setType.add(ConstantsActivityTimeline.SET_TYPE_NOTE);
            setType.add(ConstantsActivityTimeline.SET_TYPE_CALL);
            setType.add(ConstantsActivityTimeline.SET_TYPE_EMAIL);
            setType.add(ConstantsActivityTimeline.SET_TYPE_SSC_EMAIL);
            setType.add(ConstantsActivityTimeline.SET_TYPE_ACTION_PLAN);

        }
        
        if(pastActivities!=null){
            pastActivities = ActivityTimelineUtility.getDateFilterConverted(pastActivities);
            system.debug('--> after converted pastActivitiesFilter='+pastActivities);
        }
        
        system.debug('--> setType='+setType);
        system.debug('--> pastActivities='+pastActivities);
        
        // Sets up boolean to be used
        boolean slm = setType.contains(ConstantsActivityTimeline.SET_TYPE_SLM)?true:false;
        boolean hasAttachment = setType.contains(ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT)?true:false;
        boolean isDueDate = dateType=='dueDate'?true:false;
        
        List<ActivityCustomDataRowWrapper> records = new List<ActivityCustomDataRowWrapper>();
        
        // Query for relationship id's to be used for searching for activities
        ActivityTimelineUtility.ActivityIdSetObj idSets = ActivityTimelineUtility.getActivityRelationships(recordId, false);
        system.debug('--> idSets='+idSets);  

        // Convert the Start and End Date strings to Date format
        Date sDate = startDate != null && String.isNotBlank(startDate)? Date.valueOf(startDate):null;
        Date eDate = enddate != null && String.isNotBlank(enddate) ? Date.valueOf(enddate):null;        

          // Search for Tasks
        system.debug('SEARCH FOR TASKS ...');  
        List<Task> finaltaskList = new List<Task>();
        List<Task> taskList = new List<Task>();
        if (ActivityTimelineUtility.isTaskSetType(setType) ) 
        {
            system.debug('--> Calling ActivityTimelineUtility.retrieveTasks ... ');  
             system.debug('--> Calling ActivityTimelineUtility.rowLimit ... '+rows);
              system.debug('--> Calling ActivityTimelineUtility.rowOffset ... '+rows);
            finaltaskList = ActivityTimelineUtility.retrieveTasksLazyLoad(idSets, null, ConstantsActivityTimeline.DATE_RANGE_ALL, 
                                                             pastActivities, searchTerm, false,
                                                             dateType, sDate, eDate, createdBy, assignedTo, isDueDate,rows,offset,sortBy,sortDirection);
        
            if(finaltaskList != null && finaltaskList.size() > 0)
            {

                 for (Task taskObj: finaltaskList) 
            {
                 if(ActivityTimelineUtility.isTaskOrCall(taskObj, setType))
                 {
                    system.debug('settypeee---->'+setType);
                    taskList.add(taskObj);
                 }

                else if(ActivityTimelineUtility.isTaskDocument(taskObj, setType))
                 {
                    system.debug('settypeee---->'+setType);
                    taskList.add(taskObj);
                 }

                 else if(ActivityTimelineUtility.isTaskLogACall(taskObj, setType))
                 {
                    system.debug('settypeee---->'+setType);
                     taskList.add(taskObj);

                 }
                 else if(ActivityTimelineUtility.isTaskNote(taskObj, setType))
                 {
                    system.debug('settypeee---->'+setType);
                     taskList.add(taskObj);

                 }

            }


            }
        }
        system.debug('--> taskList.size()='+taskList.size());
        

        // Query Events
        List<Event> eventList = new List<Event>();
        if (ActivityTimelineUtility.isEventSetType(setType) ) 
        {
            eventList = ActivityTimelineUtility.retrieveEventsLazyLoad(idSets, null, ConstantsActivityTimeline.DATE_RANGE_ALL, 
                                                               pastActivities, searchTerm, false,
                                                               dateType, sDate, eDate, createdBy, assignedTo, isDueDate,rows,offset,sortBy,sortDirection);
        }
        system.debug('--> eventList.size()='+eventList.size());

        
        List<ActionPlan__c> actionPlanList = new List<ActionPlan__c>();
        if (ActivityTimelineUtility.isActionPlanSetType(setType) ) 
        {
            ActivityTimelineUtility.ActionPlanRelatedInfo apInfo 
                        = ActivityTimelineUtility.retrieveActionPlansLazyLoad(idSets, null, ConstantsActivityTimeline.DATE_RANGE_ALL, 
                                                                      pastActivities, searchTerm, false,
                                                                      dateType, sDate, eDate, createdBy, assignedTo, isDueDate,rows,offset,sortBy,sortDirection);
            if (apInfo != null && apInfo.actionPlans != null && apInfo.actionPlans.size() > 0 )
            {
                actionPlanList = apInfo.actionPlans;
            }
        }
        system.debug('--> actionPlanList.size()='+actionPlanList.size());
        
        // Query Emails
        List<EmailMessage> emailList = new List<EmailMessage>();
        if (ActivityTimelineUtility.isEmailSetType(setType) ) 
        {
            ActivityTimelineUtility.EmailRelatedInfo emailInfo 
                		= ActivityTimelineUtility.retrieveEmailsLazyLoad(idSets, null, ConstantsActivityTimeline.DATE_RANGE_ALL, 
                                                                 pastActivities, searchTerm, recordId, false,
                                                                 dateType, sDate, eDate, createdBy, assignedTo, isDueDate,rows,offset,sortBy,sortDirection);
            emailList = emailInfo.emailList;
        }
        system.debug('--> emailList.size()='+emailList.size());
        
        // Search for IER's
        List<et4ae5__IndividualEmailResult__c> ierList = new List<et4ae5__IndividualEmailResult__c>();
      if (ActivityTimelineUtility.isSSCEmailSetType(setType) ) {
    // if (setType.contains(ConstantsActivityTimeline.SET_TYPE_SSC_EMAIL) && !setType.contains(ConstantsActivityTimeline.SET_TYPE_EMAIL)) //- Commented to add with filter logic
        {
              system.debug('--> going to query IER');
            ierList = ActivityTimelineUtility.retrieveIERsLazyLoad(idSets, null, ConstantsActivityTimeline.DATE_RANGE_ALL, 
                                                               pastActivities, searchTerm, recordId, false,
                                                               dateType, sDate, eDate, createdBy, assignedTo, isDueDate,rows,offset,sortBy,sortDirection);
            
        }
        
        system.debug('--> ierList.size()='+ierList.size());}
        
        
        // Prepare logic to filter out Tasks or Events that has SLM or attachments
        Map<String, ActivityTimelineUtility.TaskEventEmailRelatedInfo> taskEventInfoMap 
            		= ActivityTimelineUtility.populateTaskEventRelatedInfoMap(recordId, taskList, eventList, emailList, false);
        
        system.debug('taskEventInfoMap=' + taskEventInfoMap );
        
        // Process the tasks to filter out Tasks that has SLM and Has Attachments
        if (slm || hasAttachment)
        {
            system.debug('--> Filter Out ONLY tasks and events or emails with SLM or Attachments');
            taskList = filterForTasksWithAttachmentOrSLM(setType, taskList, taskEventInfoMap);
            eventList = filterForEventsWithAttachmentOrSLM(slm, hasAttachment, eventList, taskEventInfoMap);
            emailList = filterForEmailsWithAttachment(hasAttachment, emailList, taskEventInfoMap);
        }
        
        // Process the various lists and combine them into a master list of wrapper objects
        if ( !taskList.isEmpty() )
        {
           // records = getTaskRecords(taskList, 'Task', records);
            records = getTaskRecordsNew(taskList, 'Task', records);
        }

        if ( !eventList.isEmpty() )
        {
            records = getEventRecords(eventList, 'Event', records);
        }
        
        if( !actionPlanList.isEmpty() && !hasAttachment && !slm)
        {
            records = getAPRecords(actionPlanList, 'Action Plan', records);
        }    
        
        if( !emailList.isEmpty())
        {
            records = getEmailRecords(emailList, 'Email Message', records);
        }         
        
        if( !ierList.isEmpty() && !hasAttachment && !slm)
        {
            records = getIERRecords(ierList, 'IER', records);
        }

        //sorting logic
        ActivityCustomDataRowWrapper.sortField = sortBy;
        ActivityCustomDataRowWrapper.isAsc = sortDirection.equalsIgnoreCase('asc') ? true : false;
        records.sort();
        
        //pagination logic
        Integer startIndex = Math.min(offset, records.size());
        Integer endIndex = Math.min(offset + rows, records.size());

        List<ActivityCustomDataRowWrapper> allRecords = new List<ActivityCustomDataRowWrapper>();
        for (Integer i = startIndex; i < endIndex; i++){
            allRecords.add(records[i]);
        }

        System.debug('offset:' + offset + ', LIMIT: ' + rows + ', startIndex: ' + startIndex + ', endIndex: ' + endIndex);

        return allRecords;
    }


    
    /*
     * Filters out the list of Tasks for SLM only or Has Attachments
     */  
    private static List<Task> filterForTasksWithAttachmentOrSLM(Set<String> setType, List<Task> taskList, 
                                                               Map<String, ActivityTimelineUtility.TaskEventEmailRelatedInfo> taskEventInfoMap )
    {
        system.debug('*** filterForTasksWithAttachmentOrSLM() - START ***');
        system.debug('-->setType=' + setType);
        
        List<Task> filteredTasks = new List<Task>();
        Integer i=0;
        for (Task taskObj: taskList )
        {
            system.debug(i+ '-->taskObj.Subject=' + taskObj.Subject);
            Boolean includeInFinalList = false;
                
            if ( ActivityTimelineUtility.isSlmSetType(setType) )
            {
                system.debug(i+ '-->taskObj.Phone_Call__c=' + taskObj.Phone_Call__c);
                system.debug(i+ '-->taskObj.Review__c=' + taskObj.Review__c);
                if (taskObj.Phone_Call__c || taskObj.Review__c) {
                    system.debug(i+ '-->taskObj has SLM!!!!!!!!!!!!!!');
                    includeInFinalList = true;
                }
            }
            if ( ActivityTimelineUtility.isHasAttachmentSetType(setType) )
            {
                ActivityTimelineUtility.TaskEventEmailRelatedInfo taskInfo = taskEventInfoMap.get(taskObj.Id);
                if ( taskInfo != null && taskInfo.hasAttachments ) {
                    system.debug(i+ '-->taskObj has ATTACHMENTS!!!!!!!!!!!!!!');
                    includeInFinalList = true;
                }
            }
            
            if ( includeInFinalList )
            {
                filteredTasks.add(taskObj);
            }
             
            i++;
        }
        
        return filteredTasks;
    }
    
    
    /*
     * Filters out the list of Events for SLM only or Has Attachments
     */  
    private static List<Event> filterForEventsWithAttachmentOrSLM(Boolean slm, Boolean hasAttachment, List<Event> eventList, 
                                                                 Map<String, ActivityTimelineUtility.TaskEventEmailRelatedInfo> taskEventInfoMap )
    {
        List<Event> filteredEvents = new List<Event>();
        for (Event eventObj: eventList )
        {
            Boolean hasAttachmentsOrSLM = false;
            if ( slm )
            {
                if (eventObj.Phone_Call__c || eventObj.Review__c) {
                    hasAttachmentsOrSLM = true;
                }
            }
            if ( hasAttachment )
            {
                ActivityTimelineUtility.TaskEventEmailRelatedInfo taskInfo = taskEventInfoMap.get(eventObj.Id);
                if ( taskInfo != null && taskInfo.hasAttachments ) {
                    hasAttachmentsOrSLM = true;
                }
            }
            
            if ( hasAttachmentsOrSLM )
            {
                filteredEvents.add(eventObj);
            }
                
        }
        
        return filteredEvents;
    }
    
    
    /*
     * Filters out the list of Emails for SLM only or Has Attachments
     */  
    private static List<EmailMessage> filterForEmailsWithAttachment(Boolean hasAttachment, List<EmailMessage> emailList, 
                                                                  Map<String, ActivityTimelineUtility.TaskEventEmailRelatedInfo> taskEventInfoMap )
    {
        List<EmailMessage> filteredEmails = new List<EmailMessage>();
        for (EmailMessage emailObj: emailList )
        {
            Boolean hasAttachments = false;
            if ( hasAttachment )
            {
                ActivityTimelineUtility.TaskEventEmailRelatedInfo info = taskEventInfoMap.get(emailObj.Id);
                if ( info != null && info.hasAttachments ) {
                    hasAttachments = true;
                }
            }
            
            if ( hasAttachments )
            {
                filteredEmails.add(emailObj);
            }
                
        }
        
        return filteredEmails;
    }

    
    /*
     * Converts a list of data objects into ActivityCustomDataRowWrapper objecrs
     */  
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getIERRecords( List<et4ae5__IndividualEmailResult__c> finalList, String type, 
                                                                  List<ActivityCustomDataRowWrapper> records)
    {
         System.debug('In IER----------->');
         for(et4ae5__IndividualEmailResult__c rr :finalList)
         {
          
            ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
            drw.subjectUrl = '/' + rr.get('Id');
            drw.recordId = (String)rr.get('Id');
            drw.lastModifiedDate = String.valueOf(rr.get('LastModifiedDate'));
            system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
            drw.type = type;
            drw.subtype = rr.subtype__c;
            drw.subject =  rr.get('Used_Subject_Line__c')!=null?(String)rr.get('Used_Subject_Line__c'):null;
            drw.assignedTo = rr.createdby.Name;
            drw.dueDate = rr.et4ae5__DateSent__c!=null?((DateTime)rr.get('et4ae5__DateSent__c')).format('yyyy-MM-dd'):null;
            drw.profileName = rr.et4ae5__Contact__r.Name!=null?rr.et4ae5__Contact__r.Name:NULL;
            drw.recurringTask = false;
	        drw.IsPinned = rr.Is_Pinned__c!=null?rr.Is_Pinned__c:false;
            drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
            drw.pinnedDate = rr.Pinned_Date__c!=null?String.valueOf(rr.get('Pinned_Date__c')):null;
            system.debug('IER rr.pinneddate = '+rr.Pinned_Date__c);
          //  system.debug('task rr.pinneddate = '+rr.Pinned_Date__c);
            records.add(drw);
         }
         return records;
    }


     /*
     * Converts a list of task objects into ActivityCustomDataRowWrapper objecrs
     */  
    /*
   
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getTaskRecords(List<Task> finalList, String type, 
                                                                  List<ActivityCustomDataRowWrapper> records)
        
    {
  
         for(task rr :finalList)
         {
            ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
            drw.subjectUrl = '/' + rr.get('Id');
            drw.recordId = (String)rr.get('Id');
            drw.lastModifiedDate = String.valueOf(rr.get('LastModifiedDate'));
            system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
            drw.type = type;
            drw.subtype = rr.RecordTypeId == ConstantsActivityTimeline.DOC_RECORD_TYPE_ID ? rr.Document_Type__c : rr.RecordTypeId == ConstantsActivityTimeline.TASK_RECORD_TYPE_ID ? rr.Type : type;
            drw.subject =rr.get('Subject')!=null?(String)rr.get('Subject'):null;
            drw.dueDate = rr.get('ActivityDate')!=null?String.valueOf( rr.get('ActivityDate')).removeEnd(' 00:00:00'):null;
            drw.profileName = rr.who.name!=null?rr.who.name:rr.what.name;
            drw.description = rr.get('Description')!=null?(String)rr.get('Description'):null;
            drw.assignedTo = rr.get('Assigned_To_Email_Name__c')!=null?(String)rr.get('Assigned_To_Email_Name__c'):null;
            drw.status = rr.get('Status')!=null?(String)rr.get('Status'):null;
            //drw.type =  rr.get('TaskSubtype')!=null?(String)rr.get('TaskSubtype'):null;            
	        drw.isPinned = rr.Is_Pinned__c!=null?rr.Is_Pinned__c:false;
            drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
            system.debug('task rr.pinneddate = '+rr.Pinned_Date__c);
            drw.pinnedDate = rr.Pinned_Date__c!=null?String.valueOf(rr.get('Pinned_Date__c')):null;
             //Logic for recurring task
            if(rr.IsRecurrence == true){
              Task childTasks = ActivityTimelineUtility.getChildTask(rr.Id);
              drw.recurringTask = true;
              drw.taskId = rr.Id;

              
              //add info from most recent child task instead
              drw.subjectUrl = '/' + childTasks.Id;
              //drw.recordId = childTasks.Id;
              // populate the For field from child task of recurrence series
              drw.profileName = childTasks.who.name!=null?childTasks.who.name:childTasks.what.name;
              drw.subject =childTasks.Subject;
              drw.description = childTasks.Description;
              drw.status =  childTasks.Status;
              drw.dueDate = String.valueOf(childTasks.ActivityDate);
            }
            else{
                drw.recurringTask = false;
            }
             
           // drw.dueDateValue = rr.ActivityDate;
            records.add(drw);
         }
         return records;
    }
       */
      /*
     * Converts a list of task objects into ActivityCustomDataRowWrapper objects -- new recurring logic
     */  
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getTaskRecordsNew(List<Task> finalList, String type, 
                                                                  List<ActivityCustomDataRowWrapper> records)
        
    {  
        List<task> nonRecurringTasks = new List<Task>();
        List<task> recurringTasks = new List<Task>();
        List<task> recurringCompletedParentTasks = new List<Task>();
        List<ActivityCustomDataRowWrapper> wapper1 = new List<ActivityCustomDataRowWrapper>();
        List<ActivityCustomDataRowWrapper> wapper2 = new List<ActivityCustomDataRowWrapper>();
        List<ActivityCustomDataRowWrapper> wapper3 = new List<ActivityCustomDataRowWrapper>();
       
        for(task rr :finalList)
         {
           system.debug('rr.id='+rr.id+ ' status'+rr.status);
           if(rr.RecurrenceActivityId!=null && rr.IsRecurrence ==true){
                system.debug('Recurring parent '+rr.id);
                recurringCompletedParentTasks.add(rr);

           }else if(rr.RecurrenceActivityId!=null && (rr.Status !='Completed' && rr.Status !='Complété' ) ){
            system.debug('RecurrenceActivityId!=null and status !=complete'+rr.id);
             recurringTasks.add(rr);

           }
           else{
             system.debug('RecurrenceActivityId==null or status =complete'+rr.id);
             nonRecurringTasks.add(rr);
           }
          
         }
         system.debug('$$$$recurringTasks='+recurringTasks);
         system.debug('$$$$nonRecurringTasks='+nonRecurringTasks);
         system.debug('$$$$recurringCompletedParentTasks='+recurringCompletedParentTasks);
         

         system.debug('$$$$recurringTasks size='+recurringTasks.size());
         system.debug('$$$$nonRecurringTasks size='+nonRecurringTasks.size());
         system.debug('$$$$recurringCompletedParentTasks='+recurringCompletedParentTasks.size());
         if(recurringTasks.size()>0){
            wapper1 = getRecurringTask(recurringTasks, type);
            system.debug('wapper1='+wapper1);
            records.addAll(wapper1);
         }

          if(nonRecurringTasks.size()>0){
            wapper2 = getTaskCompleteRecurring(nonRecurringTasks, type);
             records.addAll(wapper2);
         }
         if(recurringCompletedParentTasks.size()>0){
            wapper3 = getRecurringTaskParent(recurringCompletedParentTasks, type);
            records.addAll(wapper3);
         }

         return records;
    }

    /**
     * method to handle non-recurring task and complete recurring child tasks
     * 
     */
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getTaskCompleteRecurring(List<Task> finalList, String type){

      List<ActivityCustomDataRowWrapper> wrapper1 = new List<ActivityCustomDataRowWrapper>();
      for(task rr :finalList)
       {
          ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
          drw.subjectUrl = '/' + rr.get('Id');
          drw.recordId = (String)rr.get('Id');
          drw.lastModifiedDate = String.valueOf(rr.get('LastModifiedDate'));
          system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
          drw.type = type;
          drw.subtype = rr.RecordTypeId == ConstantsActivityTimeline.DOC_RECORD_TYPE_ID ? rr.Document_Type__c : rr.RecordTypeId == ConstantsActivityTimeline.TASK_RECORD_TYPE_ID ? rr.Type : type;
          drw.subject =rr.get('Subject')!=null?(String)rr.get('Subject'):null;
          drw.dueDate = rr.get('ActivityDate')!=null?String.valueOf( rr.get('ActivityDate')).removeEnd(' 00:00:00'):null;
          drw.profileName = rr.who.name!=null?rr.who.name:rr.what.name;
          drw.description = rr.get('Description')!=null?(String)rr.get('Description'):null;
          drw.assignedTo = rr.get('Assigned_To_Email_Name__c')!=null?(String)rr.get('Assigned_To_Email_Name__c'):null;
          drw.status = rr.get('Status')!=null?(String)rr.get('Status'):null;           
          drw.isPinned = rr.Is_Pinned__c!=null?rr.Is_Pinned__c:false;
          drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
          system.debug('task rr.pinneddate = '+rr.Pinned_Date__c);
          drw.pinnedDate = rr.Pinned_Date__c!=null?String.valueOf(rr.get('Pinned_Date__c')):null;
          drw.recurringTask = false;
          wrapper1.add(drw);
       }
      return wrapper1;
  }

    /**
     * method to handle non-complete recurring task
     * 
     */
    @TestVisible
        private static List<ActivityCustomDataRowWrapper> getRecurringTask(List<Task> finalList, String type){
        // build the recurring task list first
        Map<Id, List<Task>> taskMap = new  Map<Id, List<Task>>();
        for(task rr :finalList)
        {  
            if(!taskMap.containsKey(rr.RecurrenceActivityId)){
                taskMap.put(rr.RecurrenceActivityId, new List<Task>());
            }
            taskMap.get(rr.RecurrenceActivityId).add(rr);
            system.debug('setting map for task id='+rr.id);
        }
        system.debug('**** recurringTasksMap'+taskMap);

        // go through all recurring tasks map 
       

        List<Task> validChildTaskLists = new List<Task>();
        for(Id parentId:taskMap.keySet()){
            List<Task> taskList = taskMap.get(parentId);
            Task validChildTask = new Task();
            for(task rr :taskList){
                if(validChildTask.activityDate==null){
                    validChildTask = rr;
                }else{
                    if (rr.activityDate<validChildTask.activityDate){
                        validChildTask = rr;
                    }
                }
               
            }
            validChildTaskLists.add(validChildTask);

        }

        List<ActivityCustomDataRowWrapper> wrapper2 = new List<ActivityCustomDataRowWrapper>();
        if(validChildTaskLists.size()>0){
            for(Task tt: validChildTaskLists){
                ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
              
                drw.recordId = (String)tt.get('Id');
                drw.lastModifiedDate = String.valueOf(tt.get('LastModifiedDate'));
                system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
                drw.type = type;
                drw.subtype = tt.RecordTypeId == ConstantsActivityTimeline.DOC_RECORD_TYPE_ID ? tt.Document_Type__c : tt.RecordTypeId == ConstantsActivityTimeline.TASK_RECORD_TYPE_ID ? tt.Type : type;
                drw.profileName = tt.who.name!=null?tt.who.name:tt.what.name;
                drw.assignedTo = tt.get('Assigned_To_Email_Name__c')!=null?(String)tt.get('Assigned_To_Email_Name__c'):null;
                           
                drw.isPinned = tt.Is_Pinned__c!=null?tt.Is_Pinned__c:false;
                drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
                system.debug('task tt.pinneddate = '+tt.Pinned_Date__c);
                drw.pinnedDate = tt.Pinned_Date__c!=null?String.valueOf(tt.get('Pinned_Date__c')):null;
                
                drw.recurringTask = true;
                drw.taskId = tt.RecurrenceActivityId;
                drw.subjectUrl = '/' + tt.Id;               
                drw.subject =tt.Subject;
                drw.description = tt.Description;
                drw.status =  tt.Status;
                drw.dueDate = String.valueOf(tt.ActivityDate);
                // sorting
                List<Task> tl = taskMap.get(tt.RecurrenceActivityId);
                tl.sort(new RecurringTasksComparator2());
                drw.recurringTasks = tl;
                wrapper2.add(drw);
            }

        }
   
         system.debug('$$$$validChildTasklist='+validChildTaskLists);           
         
        return wrapper2;
    }

      /**
     * method to handle non-complete recurring task
     * 
     */
    @TestVisible
        private static List<ActivityCustomDataRowWrapper> getRecurringTaskParent(List<Task> finalList, String type){
       

        List<ActivityCustomDataRowWrapper> wrapper3 = new List<ActivityCustomDataRowWrapper>();
        if(finalList.size()>0){
            for(Task tt: finalList){
                ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
              
                drw.recordId = (String)tt.get('Id');
                drw.lastModifiedDate = String.valueOf(tt.get('LastModifiedDate'));
                system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
                drw.type = type;
                drw.subtype = tt.RecordTypeId == ConstantsActivityTimeline.DOC_RECORD_TYPE_ID ? tt.Document_Type__c : tt.RecordTypeId == ConstantsActivityTimeline.TASK_RECORD_TYPE_ID ? tt.Type : type;
                drw.profileName = tt.who.name!=null?tt.who.name:tt.what.name;
                drw.assignedTo = tt.get('Assigned_To_Email_Name__c')!=null?(String)tt.get('Assigned_To_Email_Name__c'):null;
                           
                drw.isPinned = tt.Is_Pinned__c!=null?tt.Is_Pinned__c:false;
                drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
                system.debug('task tt.pinneddate = '+tt.Pinned_Date__c);
                drw.pinnedDate = tt.Pinned_Date__c!=null?String.valueOf(tt.get('Pinned_Date__c')):null;
                
                drw.recurringTask = true;
                drw.taskId = tt.RecurrenceActivityId;
                drw.subjectUrl = '/' + tt.Id;               
                drw.subject =tt.Subject;
                drw.description = tt.Description;
                drw.status =  tt.Status;
                drw.dueDate = String.valueOf(tt.ActivityDate);
                // sorting
              
               // tl.sort(new RecurringTasksComparator());
               // drw.recurringTasks = tl;
                wrapper3.add(drw);
            }

        }
        return wrapper3;
    }

     /*
     * Converts a list of event objects into ActivityCustomDataRowWrapper objecrs
     */  
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getEmailRecords(List<EmailMessage> finalList, String type, 
                                                                  List<ActivityCustomDataRowWrapper> records)
        
    {
  
         for(EmailMessage rr :finalList)
         {
            ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
            drw.subjectUrl = '/' + rr.get('Id');
            drw.recordId = (String)rr.get('Id');
            drw.lastModifiedDate = String.valueOf(rr.get('LastModifiedDate'));
            system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
            drw.type = type;
            drw.subtype = rr.subtype__c;
            drw.subject =  rr.get('Subject')!=null?(String)rr.get('Subject'):null;                    
            drw.status =  rr.get('Status')!=null?(String)rr.get('Status'):null;
            drw.assignedTo = ((EmailMessage)rr).createdby.Name;
            drw.dueDate = rr.get('Message_Sent_Date__c')!=null?String.valueOf( rr.get('Message_Sent_Date__c')).removeEnd(' 00:00:00'):null;
            drw.profileName = rr.RelatedTo.Name!=null?rr.RelatedTo.Name:null;
            drw.description = rr.textBody;   //adding note/body to be available in email
            //drw.dueDateValue = rr.Message_Sent_Date__c;
	        drw.recurringTask = false;
            drw.isPinned = rr.Is_Pinned__c!=null?rr.Is_Pinned__c:false;
            drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
            drw.pinnedDate = rr.Pinned_Date__c!=null?String.valueOf(rr.get('Pinned_Date__c')):null;
            system.debug('emailmessage rr.pinneddate = '+rr.Pinned_Date__c);
            records.add(drw);
         }
         return records;
    }


    
     /*
     * Converts a list of event objects into ActivityCustomDataRowWrapper objecrs
     */  
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getAPRecords(List<ActionPlan__c> finalList, String type, 
                                                                  List<ActivityCustomDataRowWrapper> records)
        
    {
  
         for(ActionPlan__c rr :finalList)
         {
            ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
            drw.subjectUrl = '/' + rr.get('Id');
            drw.recordId = (String)rr.get('Id');
            drw.lastModifiedDate = String.valueOf(rr.get('LastModifiedDate'));
            system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
            drw.type = type;
            drw.subtype = rr.subtype__c;
            drw.subject = rr.get('Name')!=null?(String)rr.get('Name'):null;
            drw.dueDate = rr.get('StartDate__c')!=null?String.valueOf( rr.get('StartDate__c')).removeEnd(' 00:00:00'):null;
            drw.status = rr.get('Status__c')!=null?(String)rr.get('Status__c'):null;
            drw.description = rr.Description__c;  //Adding note/body to action plan records
            drw.assignedTo = ((ActionPlan__c)rr).owner.name;
            drw.profileName = rr.Name!=null?rr.Name:null;
	        drw.recurringTask = false;
            drw.isPinned = rr.Is_Pinned__c!=null?rr.Is_Pinned__c:false;
            drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
            drw.pinnedDate = rr.Pinned_Date__c!=null?String.valueOf(rr.get('Pinned_Date__c')):null;
            system.debug('actionPlan rr.pinneddate = '+rr.Pinned_Date__c);
            //drw.dueDateValue = rr.StartDate__c;
            records.add(drw);
         }
         return records;
    }

      /*
     * Converts a list of event objects into ActivityCustomDataRowWrapper objecrs
     */  
    @TestVisible
    private static List<ActivityCustomDataRowWrapper> getEventRecords(List<Event> finalList, String type, 
                                                                  List<ActivityCustomDataRowWrapper> records)
        
    {
  
         for(Event rr :finalList)
         {
            ActivityCustomDataRowWrapper drw = new ActivityCustomDataRowWrapper();
            drw.subjectUrl = '/' + rr.get('Id');
            drw.recordId = (String)rr.get('Id');
            drw.lastModifiedDate = String.valueOf(rr.get('LastModifiedDate'));
            system.debug(' drw.lastModifiedDate='+ drw.lastModifiedDate);
            drw.type = type;
            drw.subtype = rr.subtype__c;
            drw.subject =rr.get('Subject')!=null?(String)rr.get('Subject'):null;
            drw.dueDate = rr.get('ActivityDate')!=null?String.valueOf( rr.get('ActivityDate')).removeEnd(' 00:00:00'):null;
            drw.description = rr.Description;
            drw.assignedTo = rr.get('Event_Assigned_To_Email_Name__c')!=null?(String)rr.get('Event_Assigned_To_Email_Name__c'):null;
            drw.status = rr.get('Status__c')!=null?(String)rr.get('Status__c'):null;
            drw.profileName = rr.who.name!=null?rr.who.name:rr.what.name;
	        drw.recurringTask = false;
            drw.isPinned = rr.Is_Pinned__c!=null?rr.Is_Pinned__c:false;
            drw.iconName = drw.isPinned == true?'utility:pinned':'utility:pin';
            system.debug('event rr.pinneddate = '+rr.Pinned_Date__c);
            drw.pinnedDate = rr.Pinned_Date__c!=null?String.valueOf(rr.get('Pinned_Date__c')):null;
          
            //drw.dueDateValue = rr.ActivityDate;
            records.add(drw);
         }
         return records;
    }
    
    @AuraEnabled
    public static Boolean setIsPinnedTask(Id taskId, Boolean pinType)
    {
        try {
            Schema.SObjectType sObjectType = taskId.getSObjectType();
            Sobject sObjsctRecord = sObjectType.newSobject();
            sObjsctRecord.put('Id',taskId );
            sObjsctRecord.put('Is_Pinned__c', pinType);
            system.debug('calling setIsPinnedTask in controller'+ 'taskId='+taskId+' pinType='+pinType);
            if(pinType){
                sObjsctRecord.put('Pinned_Date__c',system.now());
            }
            else{
                sObjsctRecord.put('Pinned_Date__c',null);
            }
            update sObjsctRecord;
            return TRUE;
        } 
        catch (Exception e) {
            ExceptionHandler.createErrorLogRecords(e,ConstantsActivityTimeline.CUSTOM_ACTIVITY_TIMELINE,ConstantsActivityTimeline.SET_IS_PINNED_TASK, NULL);
            throw new AuraHandledException(Label.FinServ.Msg_Error_General);
        }
    }
    
      /*
     * Inner class to be returned to LWC
     */  
    public class ActivitySearchResults
    {
        @AuraEnabled
        public DataTable dataTableResponse;
        
        @AuraEnabled
        public String objectApiName;
        
        @AuraEnabled
        public String pageSizeOptions;

        @AuraEnabled
        public Boolean isGreaterThan2k;

        @AuraEnabled
        public Boolean isHousehold;

        @AuraEnabled
        public Boolean isRecurring;

        public ActivitySearchResults(String tmpObjectName)
        {
            this.objectApiName = tmpObjectName;
        }

    }  

    // sorting class

  public class RecurringTasksComparator2 implements Comparator<Task> {
    public Integer compare(Task o1, Task o2) {
        // The return value of 0 indicates that both elements are equal.
        Integer returnValue = 0;
        
       if ((o1.ActivityDate == null) && (o2.ActivityDate == null)) {
            
            returnValue = 0;
        } else if (o1.ActivityDate == null){
            // nulls-first implementation
            returnValue = -1;
        } else if (o2.ActivityDate == null){
            // nulls-first implementation
            returnValue = 1;
        } else if (o1.ActivityDate < o2.ActivityDate) {
            // Set return value to a negative value.
            returnValue = -1;
        } else if (o1.ActivityDate > o2.ActivityDate) {
            // Set return value to a positive value.
            returnValue = 1;
        }
        return returnValue;
    }

}




}