/***************************************************************************************
Class Name : ActivityTimelineUtility
Created Date : 10-02-2024
Test Class : ActivityTimelineUtilityTest
Description : 

Modification Log:

* Developer Name 	Date 		Description
-----------------------------------------------------------------------------------------
* Jeffrey Ko 		10-02-2024 	WMCSFH2-4733 - New Utility class to support Activity Timeline related code
* Jeffrey Ko        02/06/2025  WMCSFH2-5566 - Updated to include scenario to retrieve emails from converted leads
* Jeffrey Ko        02/12/2025  WMCSFH2-5610 - Fixes to ensure emails show up on Activity Timeline, and removed
*                               caching as in prod there were instances of maps being too large for caching.
* Jeffrey Ko        02/14/2025  WMCSFH2-5622 - Fix to ensure emails show up on Activity Timeline for 
*                               Additional Relationships
* Jeffrey Ko        02/14/2025  WMCSFH2-5622 - Fix to ensure emails show up on Activity Timeline for 
*                               Additional Relationships
* Prathyusha KV     05/22/2025  WMCSFH2-5844, WMCSFH2-5844 - Added methods for lazy load
* Nicole Fernandez  05/26/2025  WMCSFH2-6146 - Added a method to check for Household and update lazy load methods 
* Prathyusha KV     02-06-2025  WMCSFH2-6041,6014 changes to add marketing email filters and description for action plan and email
* Prathyusha KV     30-06-2025  WMCSFH2-6593 changes to filter out for recurring tasks
* Prathyusha KV     04-07-2025  WMCSFH2-6606 changes to render button on activity panel dynamically based on record types
* Nicole Fernandez  25-07-2025  WMCSFH2-6684 Display Logic for Recurring Tasks on Profile Panel - Upcoming Child Task
* Nicole Fernandez  07-08-2025  WMCSFH2-7013 PPR: Populating the "For" column on child task in recurring task modal
* Ramya Ravi	    14-08-2025  WMCSFH2-7127 Search Functionality (Special Characters) - Recent Activity Panel
* Sandhya Shree     19-08-2025  WMCSFH2-7110 Adding search logic for notes field on Taks
* Ramya Ravi	    25-08-2025  WMCSFH2-7227 Change SOSL to SOQL for Search functionality SOSL inconsistency
* Prathyusha KV     25-08-2025  WMCSFH2-6404 "Note" Checkbox Logic
* Sandhya Shree     04-09-2025  WMCSFH-7200  Display Subject Line for Parent Records with Completed or Unlinked recurrence Child Records
* Prathyusha KV     22-09-2025  WMCSFH2-7144,7368 Filtering emails with attachments and updating note filter to include quick note
* Lily Wu           11-09-2025  WMCSFH2-7282 Enhance Searching Logic in Recent Activities to Include Child Records for Recurring Tasks
******************************************************************************************/
public with sharing class ActivityTimelineUtility 
{
     public static final List<String> specialCharMap= new List<String>{'?','&','|','!','{','}','[',']','(',')','^','~','*',':','\"','\'','+','-'};     
     public static final List<ActivityTimelineSearch_SOQL_Fields__mdt>  SOQLSearchFieldList = [SELECT id, DeveloperName, SOQL_Fields__c FROM ActivityTimelineSearch_SOQL_Fields__mdt];    
    /*
     * This helper method will run a SOSL query against the defined object with the search key + filter criteria,
     * and returns a list of the records that has been found.
     * 
     * @param additionalFields Defines addition fields to be returned in addition to the ID field.
     */ 
    public static List<sObject> searchWithSOSL(String objectName, String searchKey, String filterCriteria, String additionalFields) 
    {
        system.debug('*** ActivityTimelineUtility.searchWithSOSL() - START  ***');
        system.debug('--> objectName=' + objectName);
        system.debug('--> searchKey=' + searchKey);
        system.debug('--> filterCriteria=' + filterCriteria);
        system.debug('--> additionalFields=' + additionalFields);
        
        String fieldsToQuery = 'Id ';
        if (!String.isBlank(additionalFields))
        {
            fieldsToQuery += ', ' + additionalFields;
        }
        system.debug('--> fieldsToQuery=' + fieldsToQuery);
        
		return WMC_Utility.getSOSLQueryResult(objectName, 'ALL', fieldsToQuery, filterCriteria, searchKey, 1999, Null);        
    }    
    
    
    
    /*
     * This method will get related activities for the specified Profile record; This method can be updated to include searching.
     * 
     * @param	profileId - Record Id of the desired data object
     * @param 	lstType - List Type to define what the query should return 
     * @param	showOnlyPinned	- If true, only show records where Is_Pinned__c = true
     * @param	dateEntered	- The data entered by the user to search
     * @param	dateToFilter - the drop down option selected by user to filter date range by
     * @param	searchText - if not empty, this will be used for searching via SOSL as well
     * @param	range - Used to drive date filtering; Possible values are Upcoming, Past, All
     */  
    public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
                                                                  String dateEntered, String dateToFilter, String searchText, 
                                                                  String range, boolean refreshData) 
    {
        system.debug('*** ActivityTimelineUtility.getRelatedActivities() - START ***');
        system.debug('000 - profileId=' + profileId);
        system.debug('000 - showOnlyPinned=' + showOnlyPinned);
        system.debug('000 - dateEntered=' + dateEntered);
        system.debug('000 - dateToFilter=' + dateToFilter);
        system.debug('000 - range=' + range);
        system.debug('000 - lstType=' + lstType);
        system.debug('000 - searchText=' + searchText);
        
        Set <String> setType = new Set <String>();
        if (lstType != NULL && lstType.size() > 0) { 
            setType.addAll(lstType);
        } else {
            setType.add(ConstantsActivityTimeline.SET_TYPE_TASK);
            setType.add(ConstantsActivityTimeline.SET_TYPE_EVENT);
            setType.add(ConstantsActivityTimeline.SET_TYPE_DOCUMENT);
            setType.add(ConstantsActivityTimeline.SET_TYPE_EMAIL);
            setType.add(ConstantsActivityTimeline.SET_TYPE_CALL);
            setType.add(ConstantsActivityTimeline.SET_TYPE_ACTION_PLAN);
            setType.add(ConstantsActivityTimeline.SET_TYPE_NOTE);
        }
        
        system.debug('000 - setType=' + setType);
        
        
        // Prepare initial variables
        system.debug('000 - Prepare initial variables ... ');
        List <ActivityDataWrapper> activtyWrapperList = new List <ActivityDataWrapper>();
        
        // Query for relationship id's to be used for searching for activities
        ActivityIdSetObj idSets = getActivityRelationships(profileId, refreshData);
        system.debug('000 - idSets=' + idSets);
        
        // activityDateFilter defines the date that the user entered manually in the UI
        Date activityDateFilter = null;
        if(!String.isBlank(dateEntered)){
            activityDateFilter = Date.valueOf(dateEntered);
        }
        system.debug('000 - activityDateFilter=' + activityDateFilter);
        
        //-----------------------------------------------------------------------------
        //---------  STEP 1. Query for Records ---------------
        
        // Query for Tasks
        List<Task> taskList = new List<Task>();
        if (isTaskSetType(setType) ==  true) 
        {
            system.debug('Query for TASKS ...');
			taskList = retrieveTasks(idSets, activityDateFilter, range, dateToFilter, searchText, showOnlyPinned,
                                     null, null, null, null, null, false);          
            system.debug('--> taskList.size()=' + taskList.size() );
        }

        // Query for EVENTS
        List<Event> eventList = new List<Event>();
        if (isEventSetType(setType) ==  true) 
        {
            system.debug('Query for EVENTS...');
            eventList = retrieveEvents(idSets, activityDateFilter, range, dateToFilter, searchText, showOnlyPinned,
                                       null, null, null, null, null, false); 
            system.debug('--> eventList.size()=' + eventList.size() );
        }
        
        // Query for Action Plans
        List<ActionPlan__c> actionPlans = new List<ActionPlan__c>();
        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (isActionPlanSetType(setType)) 
        {
            system.debug('Query for Action Plans...');
			ActionPlanRelatedInfo apInfo = retrieveActionPlans(idSets, activityDateFilter, range, dateToFilter, searchText, showOnlyPinned,
                                                               null, null, null, null, null, false);
            actionPlans = apInfo.actionPlans;
            accountMap = apInfo.accountMap;
            system.debug('--> actionPlans.size()=' + actionPlans.size() );
            system.debug('--> accountMap.size()=' + accountMap.size() );
        }       
        
        // Query for Salesforce Emails and IER's
        List<EmailMessage> emailList = new List<EmailMessage>();
        List<et4ae5__IndividualEmailResult__c> individualEmailResults = new List<et4ae5__IndividualEmailResult__c>();
        Map<Id, List<String>> emailAccountNameMap = new Map<Id,List<String>>();
        if (isEmailSetType(setType)) 
        {
            system.debug('Query for EmailMessage records ...');
            EmailRelatedInfo emailInfo = retrieveEmails(idSets, activityDateFilter, range, dateToFilter, searchText, profileId, showOnlyPinned,
                                                        null, null, null, null, null, false);
            emailList = emailInfo.emailList;
            emailAccountNameMap = emailInfo.emailAccountNameMap;
            system.debug('--> emailList.size()=' + emailList.size() );
            system.debug('--> emailAccountNameMap.size()=' + emailAccountNameMap.size() );

            
            system.debug('Query for IER records ...');
            individualEmailResults = retrieveIERs(idSets, activityDateFilter, range, dateToFilter, searchText, profileId, showOnlyPinned,
                                                  null, null, null, null, null, false);
            system.debug('--> individualEmailResults.size()=' + individualEmailResults.size() );
        }        
        
        //-----------------------------------------------------------------------------
        // STEP 2: Prepare ActivityDataWrappers that will be used by the UI
        system.debug('STEP 5: Prepare ActivityDataWrappers that will be used by the UI');
        Map<String, TaskEventEmailRelatedInfo> taskEventInfoMap 
            						= populateTaskEventRelatedInfoMap(profileId, taskList, eventList, emailList, refreshData);
       
        system.debug('555 taskEventInfoMap=' + taskEventInfoMap);
        
        // STEP 5A: TASKS
        if (isTaskSetType(setType) ==  true && taskList != null && taskList.size() > 0 ) 
        {
            system.debug('555a TASKS .... Loop through them and prepare wrappers');
            system.debug('555a taskList.size()=' + taskList.size() );
            
            Integer numberOfTasks = 0;
            for (Task taskObj: taskList) 
            {
                system.debug('555a-' + numberOfTasks + '--> taskObj=' + taskObj );
                ActivityDataWrapper wrapper =  null;
                if ( isTaskOrCall(taskObj, setType) )
                {
                    system.debug('555a-' + numberOfTasks + '--> Task or Call ... ');
                	wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.TASK, taskObj, profileId, taskEventInfoMap);
                }
                else if ( isTaskDocument(taskObj, setType) )
                {
                    system.debug('555a-' + numberOfTasks + '--> Task Document ... ');
                    wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.DC, taskObj, profileId, taskEventInfoMap);
                }
                 else if ( isTaskNote(taskObj, setType) )
                {
                    system.debug('555a-' + numberOfTasks + '--> Task Note ... ');
                    wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.DC, taskObj, profileId, taskEventInfoMap);
                }
                else if ( isTaskLogACall(taskObj, setType) )
                {
                    system.debug('555a-' + numberOfTasks + '--> Task (Log a Call) ... ');
                    wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.LOG_A_CALL, taskObj, profileId, taskEventInfoMap);
                }
                
                if ( wrapper != null )
                {
                    system.debug('555a-' + numberOfTasks + '--> Adding Task Wrapper ... wrapper=' + wrapper.activityDate + '; Subject=' + wrapper.subject);
                    activtyWrapperList.add(wrapper);
                }
                
                numberOfTasks++;
            }
        }      
        system.debug('555a activtyWrapperList.size()=' + activtyWrapperList.size() );
        
        
        // STEP 5B:  EVENTS
        if (isEventSetType(setType) && eventList != null && eventList.size() > 0 ) 
        {
            system.debug('555b EVENTS .... Loop through them and prepare wrappers');
            system.debug('555b eventList.size()=' + eventList.size() );
            
            Integer numberOfEvents = 0;
            for (Event eventObj: eventList) 
            {
                system.debug('555b-' + numberOfEvents + '--> eventObj=' + eventObj);
                ActivityDataWrapper wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.EVENT, eventObj, profileId, taskEventInfoMap);
                activtyWrapperList.add(wrapper);
                numberOfEvents++;
            }
        }
        
        system.debug('555b activtyWrapperList.size()=' + activtyWrapperList.size() );
        
        // STEP 5C:  ACTION PLANS
        system.debug('555c actionPlans.size()=' + actionPlans.size() );
        if (isActionPlanSetType(setType) && actionPlans != null && actionPlans.size() > 0 ) 
        {
            
            Integer numberOfActionPlans = 0;
            for (ActionPlan__c objActionPlan: actionPlans) 
            {
                system.debug('555c-' + numberOfActionPlans + '--> objActionPlan=' + objActionPlan);
                ActivityDataWrapper wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.ACTION_PLAN, objActionPlan, profileId, accountMap);
                activtyWrapperList.add(wrapper);
                numberOfActionPlans++;
            }
        }
        
        
        system.debug('555e Process Salesforce Emails ... emailList.size()=' + emailList.size());
        if (isEmailSetType(setType) && emailList != null && emailList.size() > 0 ) 
        {
            for (EmailMessage objEmail: emailList) 
            {
                ActivityDataWrapper wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.EMAIL, objEmail, profileId, 
                               								          taskEventInfoMap, emailAccountNameMap);
                activtyWrapperList.add(wrapper);
            }
        }
        
        system.debug('555c Process IER  Emails ...individualEmailResults.size()=' + individualEmailResults.size());
        // IER (Individual Email Result)- IER are marketing emails generated from Marketing Cloud (Distributed Marketing).
        // They are related to Contacts only (or Person Accounts).
        if (isEmailSetType(setType) && individualEmailResults != null && individualEmailResults.size() > 0)
        {
            for (et4ae5__IndividualEmailResult__c ierEmail: individualEmailResults) 
            {
                ActivityDataWrapper wrapper = new ActivityDataWrapper(ConstantsActivityTimeline.EMAIL, ierEmail);
                activtyWrapperList.add(wrapper);
            }
        }

        if (!activtyWrapperList.isEmpty()){
            activtyWrapperList.sort();
        }
        
        system.debug('555 FINAL activtyWrapperList=' + activtyWrapperList);
        return activtyWrapperList;
    }

    /*
    Method to send record type Ids to render buttons on activity panel based on record type
     */


	/*
	 * Query for Tasks records; also includes options to perhap searching via SOSL.  For search, it first
	 * uses SOSL to find the desired records, then based on the resulting Id set, it queries for fields that are needed 
	 * using SOQL. 
	 * 
	 * @param activityDateFilter - Date Filter on the Activity Timeline only
	 * @param range - for past, upcoming, or all
	 * @param dateToFilter - this is the past activities filter (i.e. Past 2 weeks)
	 * @param searchText - The string being searched for, if any
	 * @param showOnlyPinned - show records only that are marked as pinned
	 * @param dateType - Type of field to be searched for; used in Advanced Search only
	 * @param startDate - Start Date selected by user; used in advanced Search only
	 * @param endDate - Start Date selected by user; used in advanced Search only
	 * @param createdBy - Created By User selected by user; used in advanced Search only
	 * @param assignedTo - Assigned To User (Owner) selected by user; used in advanced Search only
	 * @param isDueDate
	 */  
    public static List<Task> retrieveTasks(ActivityIdSetObj idSets, Date activityDateFilter, String range, String dateToFilter,
                                           String searchText, Boolean showOnlyPinned, 
                                           String dateType, Date startDate, Date endDate, String createdBy, 
                                           String assignedTo, Boolean isDueDate)
    {
        system.debug('*** ActivityTimelineUtility.retrieveTasks() - START **');
        system.debug('222 activityDateFilter=' + activityDateFilter);
        system.debug('222 range=' + range);
        system.debug('222 dateToFilter=' + dateToFilter);
        system.debug('222 searchText=' + searchText);
        system.debug('222 dateType=' + dateType);
        system.debug('222 startDate=' + startDate);
        system.debug('222 endDate=' + endDate);
        system.debug('222 createdBy=' + createdBy);
        system.debug('222 assignedTo=' + assignedTo);
        
        //-----------------------------------------------------------------------------
        // STEP 1: Look for Task Relations based on the related Id's, used to find all related Tasks
        system.debug('STEP 1 - Query TaskRelation records');
        system.debug('222 idSets.contactIdSetTask=' + idSets.contactIdSetTask);
        system.debug('222 idSets.WhatIdSet=' + idSets.WhatIdSet);
        
        // Tasks that we want to query for
        Set<Id> taskIDSet = populateTaskIdSet(idSets);
        
        //-----------------------------------------------------------------------------
        // STEP 3: Query for Tasks (prepare query)
        system.debug('STEP 3 - Query TASK records ... ');
        Set<Id> whatIdSetTask = idSets.whatIdSetTask;
        system.debug('333 - whatIdSetTask=' + whatIdSetTask);

        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();
        
        
        String dateFieldForQuery = getDateFieldName('ActivityDate', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.TASK_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('333 - filterCriteria(After Adding More Criteria)=' + filterCriteria);

        system.debug('333 - dateFieldForQuery=' + dateFieldForQuery);

        if ( !String.isBlank(searchText) )
        {
            system.debug('333 - SEARCH USING SOSL to isolate the Task IDs first');

            // For Past Activity Filter (Picklist Option Selected)
            if( !String.isBlank(dateToFilter) )
            {
                system.debug('333b - adding (' + dateToFilter + ') to filterCriteria ... ');
                filterCriteria = filterCriteria + ' AND ActivityDate = ' + dateToFilter  + ' ';
            }
            system.debug('333b - filterCriteria(FINAL)=' + filterCriteria);
			String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING Task (Id, Subject, Status WHERE  ';
            searchquery += filterCriteria +' AND IsRecurrence = FALSE ) LIMIT 1999';
            system.debug('333 - searchquery=' + searchquery);
            List<Task> searchResults = (List<Task>)search.query(searchquery)[0];
            system.debug('333 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                system.debug('333 - Loop through searchResults ... ');
                for ( Task currTask: searchResults)
                {
                    system.debug('333a -> currTask.Id=' + currTask.Id);
                    system.debug('333a -> currTask.Subject=' + currTask.Subject);
                    system.debug('333a -> currTask.Status=' + currTask.Status);
                    searchResultsIdSet.add(currTask.Id);
                }
            }
        }
        
        system.debug('333 - searchResultsIdSet=' + searchResultsIdSet);
        system.debug('333 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        List<Task> taskList = new List<Task>();
        
        String taskQuery = 'SELECT ' + ConstantsActivityTimeline.TASK_QUERY_FIELDS + ', (SELECT id FROM TaskRelations WHERE IsWhat = FALSE) ';
        taskQuery += ' FROM Task WHERE ';

        if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            system.debug('333 DEBUG 111aaaaa');
            String searchPhraseString = '%'+searchText+'%';
            taskQuery += ' (Id IN:searchResultsIdSet OR ';
            taskQuery += '  (Subject LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else if ( String.isBlank(searchText) )
        {
            system.debug('333 DEBUG 111bbbbb');
            taskQuery += filterCriteria;
        }
        
       
        if ( range == ConstantsActivityTimeline.DATE_RANGE_UPCOMING )
        {
            system.debug('333 DEBUG UPCOMING ....');
            taskQuery += ' AND IsClosed=false AND ( ActivityDate > TODAY OR status != \'COMP\') ';    
        }
        else if ( range == ConstantsActivityTimeline.DATE_RANGE_PAST )
        {
            system.debug('333 DEBUG PAST ... ');
            taskQuery += ' AND IsClosed=true ';    
            
            // For Filter Range 
            if(String.isNotBlank(dateToFilter)){
                
                if ( !isStartDateFilterForPastYears(dateToFilter) )
                {
                    taskQuery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                        +' OR  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                        + '  AND ActivityDate >  TODAY ) )  ' ;                                   
                }
                else
                {
                    taskQuery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                        + '  OR ActivityDate = THIS_YEAR )  ' ;                                   
                }
            }
        }
        
        if(showOnlyPinned)
        {
            taskQuery = taskQuery + ' AND Is_Pinned__c=TRUE ';
        }
        
        taskQuery += ' AND ( IsArchived=TRUE OR IsDeleted=FALSE ) ';
        taskQuery += ' ORDER BY ActivityDate DESC ALL ROWS ';
        
        system.debug('333 - taskQuery=' + taskQuery);
        taskList = Database.query(taskQuery);
        system.debug('333 - taskList.size()=' + taskList.size());

        if (!String.isBlank(searchText) && !taskList.isEmpty()) {
            String lowerSearch = searchText.toLowerCase();
            List<Task> filteredTaskList = new List<Task>();
            for (Task t : taskList) {
                if (t.Subject != null && t.Subject.toLowerCase().contains(lowerSearch)) {
                    filteredTaskList.add(t);
                }
            }
            taskList = filteredTaskList;
        }
        
        return taskList;
    }
    
    
    /*
     * Query for Events
     */  
    public static List<Event> retrieveEvents(ActivityIdSetObj idSets, Date activityDateFilter, String range, String dateToFilter,
                                      		String searchText, Boolean showOnlyPinned, 
                                           	String dateType, Date startDate, Date endDate, String createdBy, 
                                           	String assignedTo, Boolean isDueDate)
    {
        system.debug('*** ActivityTimelineUtility.retrieveEvents() - START **');
        system.debug('222 activityDateFilter=' + activityDateFilter);
        system.debug('222 range=' + range);
        system.debug('222 dateToFilter=' + dateToFilter);
        system.debug('222 searchText=' + searchText);
        system.debug('222 dateType=' + dateType);
        system.debug('222 endDate=' + endDate);
        system.debug('222 startDate=' + startDate);
        system.debug('222 createdBy=' + createdBy);
        system.debug('222 assignedTo=' + assignedTo);
        
        Set<Id> eventIDSet = populateEventIdSet(idSets);
        system.debug('444 - eventIDSet=' + eventIDSet);
        
        Set<Id> whatIdSetEvent = idSets.whatIdSetEvent;
        system.debug('444 - whatIdSetEvent=' + whatIdSetEvent);

        Set<Id> contactIdSet = idSets.contactIdSet;
        system.debug('444 - contactIdSet=' + contactIdSet);
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();

        String dateFieldForQuery = getDateFieldName('ActivityDate', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.EVENT_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('444 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('444 - SEARCH USING SOSL to isolate the Event IDs first');

            // For Past Activity Filter (Picklist Option Selected)
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND ActivityDate = ' + dateToFilter + ' ';
            }
            
            String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('444 - filterCriteria(FINAL111)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING Event (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('444 - searchquery=' + searchquery);
            List<Event> searchResults = (List<Event>)search.query(searchquery)[0];
            system.debug('444 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( Event currEvent: searchResults)
                {
                    searchResultsIdSet.add(currEvent.Id);
                }
            }
        }
        
        system.debug('444 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        DateTime objDateTimeNow = System.now();
        String ARMEventTypeStr = WMC_Constants.ANNUAL_REVIEW_MEETING;
        String completeStatusStr = WMC_Constants.STATUS_VALUE_COMPLETED;
        String eventQuery = 'SELECT ' + ConstantsActivityTimeline.EVENT_QUERY_FIELDS + ', (SELECT id FROM EventRelations WHERE IsWhat = FALSE)';
        eventQuery +=' FROM Event WHERE  ';
        
        if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            eventQuery += ' (Id IN:searchResultsIdSet OR ';
            eventQuery += '  (Subject LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else
        {
            eventQuery += filterCriteria;
        }        
        
        
        if ( range == ConstantsActivityTimeline.DATE_RANGE_UPCOMING )
        {
            eventQuery += ' AND ((EndDateTime > :objDateTimeNow AND ';
            eventQuery += '(Type != :ARMEventTypeStr OR Auto_Completion__c = TRUE)) OR ';
            eventQuery += ' ((Status__c !=:completeStatusStr OR Is_Attested__c = FALSE) AND ';
            eventQuery += 'Type = :ARMEventTypeStr AND Auto_Completion__c = FALSE)) ';
        }
        else if ( range == ConstantsActivityTimeline.DATE_RANGE_PAST )
        {
            eventQuery += ' AND ((EndDateTime < :objDateTimeNow AND ';
            eventQuery += ' (Type != :ARMEventTypeStr OR Auto_Completion__c = TRUE)) OR ';
            eventQuery += ' (Status__c = :completeStatusStr AND Is_Attested__c = TRUE AND ';
            eventQuery += ' Type = :WMC_Constants.ARMEventTypeStr AND Auto_Completion__c = FALSE))';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                eventquery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND ActivityDate >  TODAY ) )  ' ;                                   
            }
            else
            {
                eventquery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR ActivityDate = THIS_YEAR )  ' ;                                   
            }
        }            
        
        if(showOnlyPinned){
            eventQuery += ' AND IS_Pinned__c = TRUE ';
        }
        
        eventquery += ' AND ( IsArchived=TRUE OR IsDeleted=FALSE ) ';
        
        eventQuery +=  ' ORDER BY EndDateTime DESC ALL ROWS ';
        
        system.debug('444 - eventQuery=' + eventQuery);
        List<Event> eventList = Database.query(eventQuery);
        system.debug('444 - eventList.size()=' + eventList.size() );
        
        return eventList;
    }
    
    
    /*
     * Query for Action Plans
     */  
    public static ActionPlanRelatedInfo retrieveActionPlans(ActivityIdSetObj idSets, Date activityDateFilter, String range, 
                                                         	String dateToFilter, String searchText, boolean showOnlyPinned, 
                                                            String dateType, Date startDate, Date endDate, String createdBy, 
                                                            String assignedTo, Boolean isDueDate)
    {
        system.debug('555c Action Plans ... ');
        Set<Id> accountIdSetActionPlan = idSets.accountIdSetActionPlan;
        Set<Id> whatIdSetActionPlan = idSets.whatIdSetActionPlan;
        Set<Id> whatIdSet = idSets.whatIdSet;
        system.debug('555c accountIdSetActionPlan=' + accountIdSetActionPlan);
        system.debug('555c whatIdSetActionPlan=' + whatIdSetActionPlan);
        system.debug('555c whatIdSet=' + whatIdSet);
        
        Map<Id, Account> accountMap = getAccountMap(idSets.recordId, idSets);
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();

        String dateFieldForQuery = getDateFieldName('StartDate__c', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.ACTION_PLAN_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('555 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('555 - SEARCH USING SOSL to isolate the Record IDs for Action Plans first');
            
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND StartDate__c = ' + dateToFilter + ' ';
            }
            String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('555 - filterCriteria(FINAL)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING ActionPlan__c (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('555 - searchquery=' + searchquery);
            List<ActionPlan__c> searchResults = (List<ActionPlan__c>)search.query(searchquery)[0];
            system.debug('555 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( ActionPlan__c currAP: searchResults)
                {
                    searchResultsIdSet.add(currAP.Id);
                }
            }
        }
        
        system.debug('444 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        String queryAP = 'SELECT ' + ConstantsActivityTimeline.ACTION_PLAN_QUERY_FIELDS;
        queryAP +=' FROM ActionPlan__c WHERE ';
        
        if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            queryAP += ' (Id IN:searchResultsIdSet OR ';
            queryAP += '  (Name LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else
        {
            queryAP += filterCriteria;
        }        
        
        
        if ( range == ConstantsActivityTimeline.DATE_RANGE_UPCOMING )
        {
            queryAP +=' And Status__c != \'' + WMC_Constants.STATUS_COMPLETED + '\' ';
        }
        else if ( range == ConstantsActivityTimeline.DATE_RANGE_PAST )
        {
            queryAP +=' And Status__c = \'' + WMC_Constants.STATUS_COMPLETED + '\' ';
        }
        
        if( activityDateFilter != null ){
            queryAP += ' And StartDate__c =:activityDateFilter';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                queryAP +=  ' AND  ( StartDate__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( StartDate__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND StartDate__c >  TODAY ) )  ' ;                                   
            }
            else
            {
                queryAP +=  ' AND  ( StartDate__c = '+ String.escapeSingleQuotes(dateToFilter) + ' OR StartDate__c = THIS_YEAR) ' ;
            }            
        }
        
        if(showOnlyPinned){
            queryAP += ' AND Is_Pinned__c = TRUE ';
        }
        queryAP += ' ORDER BY StartDate__c DESC ';
        
        system.debug('555c query(ActionPlans)=' + queryAP);
        
        List<ActionPlan__c> actionPlans = Database.query(queryAP);
        system.debug('555c actionPlans.size()=' + actionPlans.size());

		ActionPlanRelatedInfo apInfo = new ActionPlanRelatedInfo(actionPlans, accountMap);
        
        return apInfo;
    }
    
    
    /*
     * Query for IER records (Marketing Emails)
     */  
    public static List<et4ae5__IndividualEmailResult__c> retrieveIERs(ActivityIdSetObj idSets, Date activityDateFilter, String range, 
                                                                      String dateToFilter, String searchText, String profileId, Boolean showOnlyPinned, 
                                                                      String dateType, Date startDate, Date endDate, String createdBy, 
                                                                      String assignedTo, Boolean isDueDate)
    {
        system.debug('*** retrieveIERs() - GO!!! ***');
        List<et4ae5__IndividualEmailResult__c> individualEmailResults = new List<et4ae5__IndividualEmailResult__c>();
        
        system.debug('666 idSets.isPersonAccount=' + idSets.isPersonAccount);

        Set<Id> contactIdSet = idSets.contactIdSet;
        system.debug('666 - contactIdSet=' + contactIdSet);
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();
        
        String dateFieldForQuery = getDateFieldName('et4ae5__DateSent__c', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.IER_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('666 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('666 - SEARCH USING SOSL to isolate the IER Record IDs first');
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND et4ae5__DateSent__c = ' + dateToFilter + ' ';
            }
            
            String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('666 - filterCriteria(FINAL)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING et4ae5__IndividualEmailResult__c (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('666 - searchquery=' + searchquery);
            List<et4ae5__IndividualEmailResult__c> searchResults = (List<et4ae5__IndividualEmailResult__c>)search.query(searchquery)[0];
            system.debug('666 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( et4ae5__IndividualEmailResult__c ier: searchResults)
                {
                    searchResultsIdSet.add(ier.Id);
                }
            }
        }
        
        system.debug('666 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        String queryIER = 'SELECT '+ ConstantsActivityTimeline.IER_QUERY_FIELDS + ' FROM et4ae5__IndividualEmailResult__c WHERE ';
        
        if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            queryIER += ' (Id IN:searchResultsIdSet OR ';
            queryIER += '  (et4ae5__SubjectLine__c LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else
        {
            queryIER += filterCriteria;
        }        
        
        if(activityDateFilter!= null){
            queryIER +=  ' AND et4ae5__DateSent__c =:activityDateFilter';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                queryIER +=  ' AND  ( et4ae5__DateSent__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( et4ae5__DateSent__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND et4ae5__DateSent__c >  TODAY ) )  ' ;                                   
                
            }
            else
            {
                queryIER +=  ' AND  ( et4ae5__DateSent__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR et4ae5__DateSent__c = THIS_YEAR ) ' ;                                   
            }            
        }
        
        if(showOnlyPinned){
            queryIER += ' AND Is_Pinned__c = TRUE ';
        }
        queryIER += ' ORDER BY et4ae5__DateSent__c DESC';
        system.debug('666 - queryIER=' + queryIER);
        individualEmailResults = Database.query(queryIER);
        
        return individualEmailResults;
    }    
    
    
    
    /*
     * Query for EmailMessage records (Salesforce Emails)
     */  
    public static EmailRelatedInfo retrieveEmails(ActivityIdSetObj idSets, Date activityDateFilter, String range, 
                                                  String dateToFilter, String searchText, String profileId, Boolean showOnlyPinned, 
                                                  String dateType, Date startDate, Date endDate, String createdBy, 
                                                  String assignedTo, Boolean isDueDate)
    {
        system.debug('777 SALESFORCE EMAILS .... Loop through them and prepare wrappers');
        Set <Id> emailMessageIdSet = new Set<Id>();
        Map<Id, List<String>> emailAccountNameMap = new Map<Id,List<String>>();
        
        // Get the relationships
        EmailIdSetObj emailObj = getEmailIdSetInfo(profileId, idSets);
        system.debug('777 - emailObj.emailMessageIdSet=' + emailObj.emailMessageIdSet );
        if ( emailObj.emailMessageIdSet != null && !emailObj.emailMessageIdSet.isEmpty()) {
            emailMessageIdSet = emailObj.emailMessageIdSet;
        }
        if ( emailObj.emailAccountNameMap != null && !emailObj.emailAccountNameMap.isEmpty()) {
            emailAccountNameMap = emailObj.emailAccountNameMap;
        }        
        
        system.debug('777 - idSets.contactIdSet.size()=' + idSets.contactIdSet.size() );
        system.debug('777 - idSets.whatIdSet.size()=' + idSets.whatIdSet.size() );
        system.debug('777 - profileId=' + profileId );
        
        system.debug('777 emailAccountNameMap.size()=' + emailAccountNameMap.size() );
        system.debug('777 emailMessageIdSet.size()=' + emailMessageIdSet.size() );
        
        Set<Id> contactIdSetEmail = idSets.contactIdSet;
        Set<Id> whatIdSet = idSets.whatIdSet;
        system.debug('777 contactIdSetEmail.size()=' + contactIdSetEmail.size() );
        system.debug('777 dateToFilter=' + dateToFilter );
        
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();

        String dateFieldForQuery = getDateFieldName('Message_Sent_Date__c', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.EMAIL_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('777 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('777 - SEARCH USING SOSL to isolate the EmailMessage IDs first');
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND Message_Sent_Date__c = ' + dateToFilter + ' ';
            }
            String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('777 - filterCriteria(FINAL)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING EmailMessage (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('777 - searchquery=' + searchquery);
            List<EmailMessage> searchResults = (List<EmailMessage>)search.query(searchquery)[0];
            system.debug('777 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( EmailMessage currEmail: searchResults)
                {
                    searchResultsIdSet.add(currEmail.Id);
                }
            }
        }
        
        system.debug('777 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        String queryEmail = 'SELECT ' + ConstantsActivityTimeline.EMAIL_QUERY_FIELDS + ', ';
        queryEmail += '(SELECT id, RelationId, Relation.Name, RelationType FROM EmailMessageRelations ';
        queryEmail += 'WHERE RelationType = \'ToAddress\'  AND RelationId != NULL) ';
        queryEmail += 'FROM EmailMessage WHERE ';
        
        if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            queryEmail += ' (Id IN:searchResultsIdSet OR ';
            queryEmail += '  (Subject LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else
        {
            queryEmail += filterCriteria;
        }        
        
        if(activityDateFilter!=null){
            queryEmail += ' And (Message_Sent_Date__c =:activityDateFilter OR MessageDate=:activityDateFilter ) ';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            system.debug('777 AAAAAA dateToFilter=' + dateToFilter );
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                system.debug('777 BBBBBBBB' );
                queryEmail +=  ' AND  ( Message_Sent_Date__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( Message_Sent_Date__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND Message_Sent_Date__c >  TODAY ) )  ' ;                                   
                
            }
            else
            {
                system.debug('777 CCCCCCCCCC - ' + String.escapeSingleQuotes(dateToFilter) );
                queryEmail +=  ' AND  ( Message_Sent_Date__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR Message_Sent_Date__c = THIS_YEAR )  ' ;                                   
            }
        }            
        
        if(showOnlyPinned){
            queryEmail += ' AND Is_Pinned__c = TRUE ';
        }
        queryEmail += ' ORDER BY MessageDate DESC';
        system.debug('777 queryEmail(EMAIL)=' + queryEmail );
        
        List<EmailMessage> emailList = Database.query(queryEmail);
        system.debug('777 emailList.size()=' + emailList.size() );
        
        // DEBUG:
        Integer emailCount=0;
        for ( EmailMessage em:emailList){
            system.debug('777 ' + emailCount + ' - em.Subject=' + em.Subject );
            emailCount++;
        }
        
        return new EmailRelatedInfo(emailList, emailAccountNameMap);
    }

    
    /*
     * Returns the Task Status picklist options in a map.  If retriving the first time, we 
     * set it to the Platform Org Cache.
     */ 
    public static Map <String, String> getTaskStatusPicklist() 
    {
        Map <String, String> picklistMap = (Map <String, String>)PlatformCacheUtility.getCache(ConstantsActivityTimeline.TASK_STATUS_PICKLIST);
        if ( picklistMap == null )
        {
            picklistMap = new Map<String, String>();
            Schema.SObjectType s = Schema.getGlobalDescribe().get(ConstantsActivityTimeline.TASK);
            Schema.DescribeSObjectResult r = s.getDescribe();
            Map <String, Schema.SObjectField> fields = r.fields.getMap();
            Schema.DescribeFieldResult fieldResult = fields.get(ConstantsActivityTimeline.STATUS).getDescribe();
            List <Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for (Schema.PicklistEntry pickListVal: ple) 
            {
                if (pickListVal.getValue() != ConstantsActivityTimeline.STATUS_COMPLETED)
                {
                    picklistMap.put(pickListVal.getLabel(), pickListVal.getValue());
                }
            }
            
            PlatformCacheUtility.setCache(ConstantsActivityTimeline.TASK_STATUS_PICKLIST, picklistMap, null);
            
        }
        
        return picklistMap;
    }
    
    
    /*
     * Returns the Contact Id based on the given Profile/Account Record ID for the person account.
     */  
    public static Id getPersonContactId(Id profileId)
    {
        	Account accountInfo = [SELECT Id, PersonContactId, RecordTypeId 
                                   FROM Account WHERE ID =: profileId WITH SECURITY_ENFORCED LIMIT 1];
        Id contactId = accountInfo.PersonContactId;
        return contactId;
    }

    /*
     * Returns the true/false based on the given Profile/Account Record ID is a household or not.
     */  
    public static Boolean checkIsHousehold(Id profileId)
    {
        Boolean isHousehold = false;
        String hhRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(WMC_Constants.HOUSEHOLD_ACC_RT).getRecordTypeId();

        Account accountInfo = [SELECT Id, RecordTypeId 
                                   FROM Account WHERE ID =: profileId WITH SECURITY_ENFORCED LIMIT 1];
        isHousehold = accountInfo.RecordTypeId == hhRecordTypeId ? true : false;
        return isHousehold;
    }
    
    /*
     * Populates an Account Name map; used for retrieveActionPlans() method only
     */  
    private static Map<Id, Account> getAccountMap(String profileId, ActivityIdSetObj idSets)
    {
        Map<Id, Account> accountMap = new Map<Id, Account>();
        
            List<Account> accountList = [SELECT Id, Name FROM Account 
                                         WHERE Id in:idSets.accountIdSetActionPlan OR Id in:idSets.whatIdSetActionPlan OR 
                                         Id IN:idSets.whatIdSet 
                                         WITH SECURITY_ENFORCED 
                                         LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
            
            if ( accountList != null && accountList.size() > 0 )
            {
            	accountMap = new Map<Id, Account>(accountList);    
        }
        
        return accountMap;
    }
    
    /*
     * Get childrecurring tasks
     */  
    /*
    public static Task getChildTask(Id parentTaskId) 
    {
        system.debug('getchildtask');
        Task childTask = new Task();
        List<Task> taskList = null;
        
        try{
        taskList = [
            SELECT Id, IsRecurrence, Subject, toLabel(Status), ActivityDate, Owner.Name, RecurrenceActivityId, Description, Who.Name, Type
            , TaskSubtype, What.Name
            FROM Task 
            WHERE RecurrenceActivityId =: parentTaskId
            AND IsRecurrence = FALSE
            AND Status !=: Label.Task_Status_Completed AND Status !=: 'CANC'
            ORDER BY ActivityDate ASC
        ];

        //check if taskList is null or not
        if(taskList != null && taskList.size() > 0){
            childTask = taskList[0];
        } else {
            // get parent task to show in the panel if no child exist
            List<Task> parentTaskList = [SELECT Id, IsRecurrence, Subject, toLabel(Status), ActivityDate, Owner.Name, RecurrenceActivityId, Description, Who.Name, Type
                                        , TaskSubtype, What.Name
                                        FROM Task 
                                        WHERE Id =: parentTaskId
                                        AND IsRecurrence = TRUE
            ];
            childTask = parentTaskList[0];
        }
        }catch(Exception exp){
            system.debug('ERROR: ' + exp.getMessage());
            ExceptionHandler.createErrorLogRecords(exp, 'ActivityTimelineUtility', 'getChildTask', null);
        }
        

        return childTask;
    }    
    */

    /**
     * Child class used to store email related relationships to be reused in queries or searches.
     */  
    @TestVisible
	private static EmailIdSetObj getEmailIdSetInfo(String profileId, ActivityIdSetObj idSets)
    {
        system.debug('777 - getEmailIdSetInfo() - profileId=' + profileId );
        system.debug('777 - getEmailIdSetInfo() - idSets=' + idSets );
        system.debug('777 - getEmailIdSetInfo() - cache key=' + ConstantsActivityTimeline.EMAIL_ID_SET_KEY+profileId );
        
        EmailIdSetObj emailObj = null;
            Set <Id> emailMessageIdSet = new Set<Id>();
            Map<Id, List<String>> emailAccountNameMap = new Map<Id,List<String>>();
            
            system.debug('getEmailIdSetInfo() - 555d - idSets.contactIdSet=' + idSets.contactIdSet );
            system.debug('getEmailIdSetInfo() - 555d - idSets.contactIdSet.size()=' + idSets.contactIdSet.size() );
            system.debug('getEmailIdSetInfo() - 555d - idSets.whatIdSet=' + idSets.whatIdSet );
            system.debug('getEmailIdSetInfo() - 555d - idSets.whatIdSet.size()=' + idSets.whatIdSet.size() );
            system.debug('getEmailIdSetInfo() - 555d - profileId=' + profileId );
        
        // For Emails, we need to check whether the record is a Profile; if so, we need to
        // check whether it is a converted lead.  If so, we need to include the emails from the
        // Lead records that have been converted.
        List<Lead> convertedLeads = [SELECT Id, Name
                                     FROM Lead 
                                     WHERE IsConverted=true AND ConvertedAccountId =:profileId];
        system.debug('getEmailIdSetInfo() - 555d - convertedLeads=' + convertedLeads );
        
        if ( convertedLeads != null && convertedLeads.size() > 0 )
        {
            for (Lead convertedLead: convertedLeads)
            {
                idSets.contactIdSet.add(convertedLead.Id);    
            }
        }
            
            // 1. First find all the EmailMessage Relations (i.e. emails related to the current record)
            if (!idSets.contactIdSet.isEmpty() || !idSets.whatIdSet.isEmpty()) 
            {
                List<EmailMessageRelation> emailRelations = [SELECT EmailMessageId 
                                                             FROM EmailMessageRelation 
                                                         WHERE RelationId IN :idSets.contactIdSet OR 
                                                             RelationId IN :idSets.whatIdSet 
                                                             LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
                system.debug('getEmailIdSetInfo() - 555d - emailRelations=' + emailRelations );
                for (EmailMessageRelation em: emailRelations) 
                {
                    emailMessageIdSet.add(em.EmailMessageId);
                }
            }
            
            system.debug('555d emailMessageIdSet=' + emailMessageIdSet );
            system.debug('555d emailMessageIdSet.size()=' + emailMessageIdSet.size() );
            
            // 2. First use SOSL to find the Email Messages (up to 1999 records) that contains the accRecord.Crm_Oid__c (used for migrated
            // Profile data only).  This is done for Profile/Account records only!
            system.debug('555d idSets.isAccount=' + idSets.isAccount );
            if ( idSets.isAccount )
            {
                system.debug('555d This is an Profile/Account ...');
                Map<String,String> accountNameMap = new Map<String,String>();
                Set<String> accountIdSet = new Set<String>();
                Map<Id,Set<String>> emailAdditionalRelationshipMap = new Map<Id, Set<String>>(); 
                
                Account profile = [Select Id, Crm_Oid__c, RecordTypeId 
                                   FROM Account 
                                   WHERE Id =:profileId  WITH SECURITY_ENFORCED LIMIT 1];
                system.debug('555d profile=' + profile);
                List<EmailMessage> tempProfileEmails = 
                    (List<EmailMessage>)searchWithSOSL('EmailMessage', profile.Crm_Oid__c, 
                                                       '', 'Additional_Relationships__c');
                
                system.debug('555d tempProfileEmails=' + tempProfileEmails);
                for(EmailMessage emRecord : tempProfileEmails){
                if(emRecord.Additional_Relationships__c != null &&
                   emRecord.Additional_Relationships__c.contains((String)profile.Crm_Oid__c)) 
                {
                        set<String> newSetString = new Set<String>(emRecord.Additional_Relationships__c.split('[\\s,;:]+'));
                        newSetString.remove('Individual');
                        newSetString.remove('Household');
                        newSetString.remove('Company');
                        emailAdditionalRelationshipMap.put(emRecord.Id, newSetString);
                        emailMessageIdSet.add(emRecord.Id);    
                    }
                }
                system.debug('555d emailAdditionalRelationshipMap=' + emailAdditionalRelationshipMap);
                
                for(Set<String> accSet : emailAdditionalRelationshipMap.values()) {
                    accountIdSet.addAll(accSet);
                }
                system.debug('555d accountIdSet=' + accountIdSet);
                
                List<Account> householdOrCompanies = [SELECT Crm_Oid__c,Name 
                                                      FROM Account 
                                                      WHERE RecordTypeId IN :ConstantsActivityTimeline.COMPANY_OR_HOUSEHOLD_RECORD_TYPE_SET AND 
                                                      Crm_Oid__c IN :accountIdSet WITH SECURITY_ENFORCED 
                                                      LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
                system.debug('555d householdOrCompanies=' + householdOrCompanies);
                
                for(Account accountRecord : householdOrCompanies) 
                {
                    accountNameMap.put(accountRecord.Crm_Oid__c, accountRecord.Name);
                }
                system.debug('555d accountNameMap=' + accountNameMap);
                
                for(Id emailRecordId : emailAdditionalRelationshipMap.keySet()){
                    for(String accountRecordId : emailAdditionalRelationshipMap.get(emailRecordId)) {
                        if(emailAccountNameMap.containsKey(emailRecordId)){
                            if(accountNameMap.containsKey(accountRecordId)) {
                                emailAccountNameMap.get(emailRecordId).add(accountNameMap.get(accountRecordId)); 
                            }
                        }
                        else{
                            emailAccountNameMap.put(emailRecordId, new List<String>{accountNameMap.get(accountRecordId)});
                        }
                    }
                }                
            }
            system.debug('555d emailAccountNameMap.size()=' + emailAccountNameMap.size() );
            system.debug('555d emailMessageIdSet.size()=' + emailMessageIdSet.size() );
            
            emailObj = new EmailIdSetObj(emailMessageIdSet, emailAccountNameMap);

		return emailObj;    
    }
    
    
    /**
     * Based on a given record Id, this method will query for related records and put the related Id's in various
     * Sets.  These will be used in subsequent queries.
     * 
     * @param recordId
     * @param refreshData - if true, clear the cache
     */  
    public static ActivityIdSetObj getActivityRelationships(Id recordId, Boolean refreshData)
    {
        system.debug('*** ActivityTimelineUtility.getActivityRelationships() - START *** ');
        system.debug('--> recordId=' + recordId);
        system.debug('--> refreshData=' + refreshData);
        
        ActivityIdSetObj idSets = new ActivityIdSetObj(recordId);
            
            // If the given Profile is a Person Account, capture the Contact ID (we need this for future queries)
            // Since this info is static, we'll save a map of Account Id to Contact Id in the Platform Cache. 
            if(recordId.getSObjectType().getDescribe().getName() == 'Account') {
                idSets.isAccount = true;
                Id contactId = ActivityTimelineUtility.getPersonContactId(recordId);
                
                if ( contactId != null )
                {
                    idSets.isPersonAccount = true;
                    idSets.contactIdSet.add(contactId);
                    idSets.contactIdSetEvent.add(contactId);
                }
            }
            else 
            {            
                idSets.contactIdSetEvent.add(recordId);
            }
            
            system.debug('--> idSets.isAccount=' + idSets.isAccount);
            
            if ( idSets.isAccount )
            {
                system.debug('111 --> Record is a Profile (Account) ...');
                
                //-----------------------------------------------------------------------------
                // STEP 1: Query for all Household Members, if this is a Household.  We need to capture
                // all related profile Id's that are related to the Household (if any), and these will
                // be used.  These relations will be cached to be used for subsequent calls to get more data.
                system.debug('STEP 1 - Query for Relationships related to the Profile ... ');
                List<AccountContactRelation> acrList = [SELECT Id, FinServ__Rollups__c, AccountId, ContactId, Contact.AccountId
                                                        FROM AccountContactRelation 
                                                        WHERE AccountId =: recordId AND FinServ__PrimaryGroup__c = TRUE AND 
                                                              IsActive = TRUE 
                                                        WITH SECURITY_ENFORCED 
                                                        LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
                system.debug('111 - acrList=' + acrList);
                
                // Populate various id maps to be used for later
                for (AccountContactRelation objACR: acrList ) 
                {
                    idSets.whatIdSet.add(objACR.Contact.AccountId);
                    idSets.contactIdSet.add(objACR.ContactId);
        
                    // Add Id's related to household member rollups.
                    if (objACR.FinServ__Rollups__c != NULL && 
                        (objACR.FinServ__Rollups__c.contains(ConstantsActivityTimeline.ALL) ||
                         objACR.FinServ__Rollups__c.contains(ConstantsActivityTimeline.TASK))) 
                    {
                        idSets.whatIdSetTask.add(objACR.Contact.AccountId);
                        idSets.contactIdSetTask.add(objACR.ContactId);
                        idSets.accountIdSetActionPlan.add(objACR.Contact.AccountId);
                        idSets.whatIdSetFinancialAccount.add(objACR.Contact.AccountId);
                    }
                    
                    if (objACR.FinServ__Rollups__c != NULL && 
                        (objACR.FinServ__Rollups__c.contains(ConstantsActivityTimeline.ALL) || 
                         objACR.FinServ__Rollups__c.contains(ConstantsActivityTimeline.EVENT))) 
                    {
                        idSets.whatIdSetEvent.add(objACR.Contact.AccountId);
                        idSets.contactIdSetEvent.add(objACR.ContactId);
                        idSets.whatIdSetFinancialAccount.add(objACR.Contact.AccountId);
                    }
                }
                
                
                //-----------------------------------------------------------------------------
                // STEP 1b: Query for all Companies where the household members are related to
                system.debug('STEP 1b - Query for Companies related to the Household Members via ACR');
                List<AccountContactRelation> acrListForContacts = null;
                acrListForContacts = [SELECT Id, AccountId, ContactId 
                                      FROM AccountContactRelation 
                                      WHERE (ContactId IN: idSets.contactIdSetTask OR 
                                             ContactId IN: idSets.contactIdSetEvent OR
                                             ContactId IN: idSets.contactIdSet) AND 
                                            FinServ__IncludeInGroup__c = TRUE AND IsActive = TRUE  WITH SECURITY_ENFORCED 
                                      LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
                
                system.debug('111b - acrListForContacts=' + acrListForContacts);
                for(AccountContactRelation objACR: acrListForContacts) 
                {
                    if(idSets.contactIdSetTask.contains(objACR.ContactId) || idSets.contactIdSetEvent.contains(objACR.ContactId)){
                        idSets.whatIdSetFinancialAccount.add(objACR.AccountId);
                    }
                    idSets.whatIdSet.add(objACR.AccountId);
                    idSets.whatIdSetEvent.add(objACR.AccountId);
                    idSets.whatIdSetTask.add(objACR.AccountId);
                    idSets.accountIdSetActionPlan.add(objACR.AccountId);
                }
                
                //-----------------------------------------------------------------------------
                // STEP 1c: Look for Tasks linked to Financial Accounts that are owned by the household members
                system.debug('STEP 1c - Look for Tasks linked to Financial Accounts that are owned by the household members');
                system.debug('111c - idSets.whatIdSetFinancialAccount=' + idSets.whatIdSetFinancialAccount);
                if(idSets.whatIdSetFinancialAccount != NULL && !idSets.whatIdSetFinancialAccount.isEmpty())
                {
                    List<FinServ__FinancialAccount__c> financialAccounts = [SELECT Id FROM FinServ__FinancialAccount__c 
                                                                            WHERE FinServ__PrimaryOwner__c IN: idSets.whatIdSetFinancialAccount 
                                                                            LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
                    system.debug('111c - financialAccounts=' + financialAccounts);
                    for(FinServ__FinancialAccount__c financialAccountRecord : financialAccounts)
                    {
                        idSets.whatIdSetTask.add(financialAccountRecord.Id);
                        idSets.whatIdSetEvent.add(financialAccountRecord.Id);
                    }
                }
            }
            else
            {
				system.debug('222 --> Record is NOT Profile (Account) ...');
                idSets.contactIdSet.add(recordId);
        }
        
        return idSets;
    }
    
    
    /**
     * Constructs the filter criteria used in search
     */  
    public static String getFilterCriteria(String initialFilters, Date activityDateFilter, Date startDate, Date endDate, 
                                           Boolean isDueDate, String dateFieldName, String assignedTo, String createdBy)
    {
        system.debug('   ---> getFilterCriteria() ... initialFilters=' + initialFilters);
        system.debug('   ---> getFilterCriteria() ... activityDateFilter=' + activityDateFilter);
        system.debug('   ---> getFilterCriteria() ... startDate=' + startDate);
        system.debug('   ---> getFilterCriteria() ... endDate=' + endDate);
        system.debug('   ---> getFilterCriteria() ... isDueDate=' + isDueDate);
        system.debug('   ---> getFilterCriteria() ... dateFieldName=' + dateFieldName);
        system.debug('   ---> getFilterCriteria() ... assignedTo=' + assignedTo);
        system.debug('   ---> getFilterCriteria() ... createdBy=' + createdBy);
        
        String filterCriteria = initialFilters;
        
        Boolean isDayOnly = true;
        if ( dateFieldName == 'CreatedDate' || dateFieldName == 'LastModifiedDate')
        {
            isDayOnly = false;
        }
        
        // Start/End Date is used by Advanced Search only!
        if(endDate!=null || startDate!=null)
        {
            system.debug('   ---> getFilterCriteria() ... 111a - Set up Date Range Filter (ADVANCED SEARCH)... ');
            String dateFilterCombined = getDateFilterQuery(activityDateFilter, startDate, endDate, isDueDate, dateFieldName, isDayOnly);
            system.debug('   ---> getFilterCriteria() ... 111a - dateFilterCombined=' + dateFilterCombined);
            filterCriteria += dateFilterCombined;
            system.debug('   ---> getFilterCriteria() ... 111a - filterCriteria=' + filterCriteria);
        } 
        else if ( activityDateFilter != null )
        {
            system.debug('   ---> getFilterCriteria() ... 111b - Set up Date Range Filter (Activity Timeline) ... ');
            String dateFilterCombined = getDateFilterQuery(activityDateFilter, null, null, isDueDate, dateFieldName, isDayOnly);
            system.debug('   ---> getFilterCriteria() ... 111b - dateFilterCombined=' + dateFilterCombined);
            filterCriteria += dateFilterCombined;
            system.debug('   ---> getFilterCriteria() ... 111b - filterCriteria=' + filterCriteria);
        }
        
        if(!String.isBlank(assignedTo)  && initialFilters!= ConstantsActivityTimeline.EMAIL_INITIAL_FILTERS){
            filterCriteria += ' AND Ownerid = \''+assignedTo + '\'';
            system.debug('   ---> getFilterCriteria() ... 222 - filterCriteria=' + filterCriteria);
        }
        if(!String.isBlank(createdBy)){
            filterCriteria += ' AND CreatedById = \'' +createdBy + '\'';
            system.debug('   ---> getFilterCriteria() ... 333 - filterCriteria=' + filterCriteria);
        }
        
        system.debug('   ---> getFilterCriteria() ... FINAL - filterCriteria=' + filterCriteria);
        return filterCriteria;
        
    }
    
    
    /*
     * Returns a map that stores the related details for Tasks/Events/Emails, where the key is the task Id, and the value
     * of the map is a TaskEventEmailRelatedInfo object
     */
    public static Map<String, TaskEventEmailRelatedInfo> populateTaskEventRelatedInfoMap(Id profileId, List<Task> taskList, 
                                                                                         List<Event> eventList, List<EmailMessage> emailList, 
                                                                                         boolean refreshData)
    {
        Set<String> taskEventEmailStringSet = new Set<String>();
        Map<String, TaskEventEmailRelatedInfo> taskEventRelatedInfoMap = null;
            taskEventRelatedInfoMap = new Map<String, TaskEventEmailRelatedInfo>();
            List<Id> emailId = new List<Id>();

            //-----------------------------------------------------------------------------
            // STEP 5: Populate taskEventStringSet that contains record Ids for both tasks, events, or Emails
            system.debug('STEP 5 - Populate taskEventEmailStringSet that contains record Ids for both tasks and events');
    
            if( taskList != null && !taskList.isEmpty()) {
                for(Task taskRecord : taskList) {
                    taskEventEmailStringSet.add(taskRecord.Id);
                    if(taskRecord.CV_Unique_Key__c != NULL && !String.isEmpty(taskRecord.CV_Unique_Key__c)) {
                        taskEventEmailStringSet.add(taskRecord.CV_Unique_Key__c);
                    }
                    if(taskRecord.Crm_Oid__c != NULL && !String.isEmpty(taskRecord.Crm_Oid__c)) {
                        taskEventEmailStringSet.add(taskRecord.Crm_Oid__c);
                    }
                }
            }
            
            if(eventList != null && !eventList.isEmpty()) {
                for(Event eventRecord : eventList) {
                    taskEventEmailStringSet.add(eventRecord.Id);
                    if(eventRecord.CV_Unique_Key__c != NULL && !String.isEmpty(eventRecord.CV_Unique_Key__c)) {
                        taskEventEmailStringSet.add(eventRecord.CV_Unique_Key__c);
                    }
                    if(eventRecord.Crm_Oid__c != NULL && !String.isEmpty(eventRecord.Crm_Oid__c)) {
                        taskEventEmailStringSet.add(eventRecord.Crm_Oid__c);
                    }
                }
            }

            if(emailList != null && !emailList.isEmpty()) {
                for(EmailMessage emailRecord : emailList) {
                    taskEventEmailStringSet.add(emailRecord.Id);
                    if(emailRecord.Crm_Oid__c != NULL && !String.isEmpty(emailRecord.Crm_Oid__c)) {
                        taskEventEmailStringSet.add(emailRecord.Crm_Oid__c);
                    }
                     if(emailRecord.HasAttachment){
                        emailId.add(emailRecord.Id);
                }

            }
            }
            
            system.debug('555 - taskEventEmailStringSet.size()=' + taskEventEmailStringSet.size() );
            
    
            //-----------------------------------------------------------------------------
            // STEP 6: Look up whether the related Tasks and Events have attachments (Document_Management__c) or Categories (Tag_With)
            system.debug('STEP 6 - Look up whether the related Tasks and Events have attachments (Document_Management__c) or Categories (Tag_With)');
            
            Set<String> taskEventAttachmentSet = new Set<String>();
            for(Document_Management__c dcRecord : [SELECT Id, Related_Record_ID__c 
                                                   FROM Document_Management__c
                                                   WHERE Related_Record_ID__c IN:taskEventEmailStringSet
                                                    AND Deleted__c = FALSE
                                                   LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()]) 
            {
                TaskEventEmailRelatedInfo teInfo = taskEventRelatedInfoMap.get(dcRecord.Related_Record_ID__c);
                if ( teInfo == null )
                {
                    teInfo = new TaskEventEmailRelatedInfo(dcRecord.Related_Record_ID__c, true);
                    taskEventRelatedInfoMap.put(dcRecord.Related_Record_ID__c, teInfo);
                }
            }
    
            for(Id emailAttachmentId : emailId){
               TaskEventEmailRelatedInfo teEmailInfo = taskEventRelatedInfoMap.get(emailAttachmentId);
                if ( teEmailInfo == null )
                {
                    teEmailInfo = new TaskEventEmailRelatedInfo(emailAttachmentId, true);
                    taskEventRelatedInfoMap.put(emailAttachmentId, teEmailInfo);
                }

            }
    
            //Creating a Map of Task, Event Ids linked with Tagged_With__c
            Map<String,List<String>> taskEventTaggedWithMap = new Map<String, List<String>>();
            for(Tagged_With__c taggedWithRecord : [SELECT id, Tag__r.name, Task_Schedule_Item__c
                                                   FROM Tagged_with__c
                                                   WHERE Task_Schedule_Item__c IN:taskEventEmailStringSet
                                                   LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()])
            {
                TaskEventEmailRelatedInfo teInfo = taskEventRelatedInfoMap.get(taggedWithRecord.Task_Schedule_Item__c);
                if ( teInfo == null )
                {
                    teInfo = new TaskEventEmailRelatedInfo(taggedWithRecord.Task_Schedule_Item__c, false);
                    teInfo.categories.add(taggedWithRecord.tag__r.name);
                    taskEventRelatedInfoMap.put(taggedWithRecord.Task_Schedule_Item__c, teInfo);
                }
                else
                {
                    teInfo.categories.add(taggedWithRecord.tag__r.name);
                    taskEventRelatedInfoMap.put(taggedWithRecord.Task_Schedule_Item__c, teInfo);
                }
            }
        
        return taskEventRelatedInfoMap;
    }
    
    
    /*
     * Based on the given idSet that contains the related Id references This helper method will 
     */  
    private static Set<Id> populateTaskIdSet(ActivityIdSetObj idSets)
    {
        Set<Id> taskIDSet = new Set<Id>();
        if (!idSets.contactIdSetTask.isEmpty() || !idSets.WhatIdSet.isEmpty()) 
        {
            List<TaskRelation> taskRelations = [SELECT TaskId 
                                                FROM TaskRelation 
                                                WHERE( RelationId IN: idSets.contactIdSetTask OR AccountId IN :idSets.WhatIdSet) AND 
                                                		Task.TaskSubtype != :ConstantsActivityTimeline.EMAIL AND 
                                                        Task.TaskSubtype != :ConstantsActivityTimeline.LIST_EMAIL 
                                                WITH SECURITY_ENFORCED
                                                LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows()];
            for (TaskRelation tr: taskRelations) 
            {
            	taskIDSet.add(tr.TaskId);
            }
            system.debug('222 taskIDSet=' + taskIDSet);
        }       
        
        return taskIDSet;
    }
    
    
    /*
     * Generate event id set based on given what ids
     */  
    private static Set<Id> populateEventIdSet(ActivityIdSetObj idSets)
    {
        Set<Id> eventIDSet = new Set<Id>();
        if (!idSets.contactIdSetEvent.isEmpty() || !idSets.WhatIdSet.isEmpty()) {
            List<EventRelation> eventRelations = [SELECT EventId 
                                                  FROM EventRelation 
                                                  WHERE (RelationId IN: idSets.contactIdSetEvent OR Accountid IN :idSets.WhatIdSet) 
                                                  WITH SECURITY_ENFORCED LIMIT: Limits.getLimitQueryRows() - Limits.getQueryRows() ];
			system.debug('444 - eventRelations=' + eventRelations);
            for (EventRelation ev: eventRelations) 
            {
                eventIDSet.add(ev.EventId);
            }
        }
        
        return eventIDSet;
    }
    
    
    
    /*
     * Returns true if the Type to search for include Tasks
     */   
    public static boolean isTaskSetType(Set<String> setType)
    {
		return (setType.contains(ConstantsActivityTimeline.SET_TYPE_TASK) || setType.contains(ConstantsActivityTimeline.SET_TYPE_CALL) || 
                setType.contains(ConstantsActivityTimeline.SET_TYPE_DOCUMENT) || setType.contains(ConstantsActivityTimeline.SET_TYPE_NOTE));
    }
    
    
    /*
     * Returns true if the Type to search for include Task (not document or call)
     */   
    public static boolean isTaskOnlySetType(Task objTask, Set<String> setType)
    {
		return (setType.contains(ConstantsActivityTimeline.SET_TYPE_TASK) && 
                objTask.RecordTypeId != NULL && !objTask.RecordTypeId.equals(ConstantsActivityTimeline.DOC_RECORD_TYPE_ID));
    }
    
    
    
    /*
     * Returns true if the Task is for a regular Task (WMC Task) or a Call (Log a Call).  If Task is a document,
     * it will not get included. 
     */       
    public static boolean isTaskOrCall(Task objTask, Set<String> setType)
    {
        system.debug('*** isTaskOrCall(Task objTask, Set<String> setType) ... ');
        
        return (objTask.Type != NULL && objTask.TaskSubtype.equalsIgnoreCase(ConstantsActivityTimeline.TASK) &&
                setType.contains(ConstantsActivityTimeline.SET_TYPE_TASK) && 
                (objTask.TaskSubtype !=NULL && !objTask.TaskSubtype.equalsIgnoreCase(ConstantsActivityTimeline.EMAIL)) && 
                (objTask.RecordTypeId !=NULL && 
                 (objTask.RecordTypeId.equals(ConstantsActivityTimeline.TASK_RECORD_TYPE_ID) || 
                  objTask.RecordTypeId.equals(ConstantsActivityTimeline.MAIL_MERGE_RECORD_TYPE_ID) ) ));
    }

    
     /*
     * Returns true if the Task is for a Note type
     */ 

    public static boolean isTaskNote(Task objTask, Set<String> setType)
    {
        return (objTask.Type != NULL && setType.contains(ConstantsActivityTimeline.SET_TYPE_NOTE) && 
                objTask.TaskSubtype != NULL && !objTask.TaskSubtype.equalsIgnoreCase(ConstantsActivityTimeline.EMAIL) && 
                objTask.RecordTypeId != NULL && objTask.RecordTypeId.equals(ConstantsActivityTimeline.DOC_RECORD_TYPE_ID) &&
                objTask.TaskSubtype.equalsIgnoreCase(ConstantsActivityTimeline.TASK) && objTask.Document_Type__c != '' && (objTask.Document_Type__c == 'Note' || objTask.Document_Type__c == 'Quick Note'));
    }
    

    
    /*
     * Returns true if the Task is for a Document type
     */       
    public static boolean isTaskDocument(Task objTask, Set<String> setType)
    {
        return (objTask.Type != NULL && setType.contains(ConstantsActivityTimeline.SET_TYPE_DOCUMENT) && 
                objTask.TaskSubtype != NULL && !objTask.TaskSubtype.equalsIgnoreCase(ConstantsActivityTimeline.EMAIL) && 
                objTask.RecordTypeId != NULL && objTask.RecordTypeId.equals(ConstantsActivityTimeline.DOC_RECORD_TYPE_ID) &&
                objTask.TaskSubtype.equalsIgnoreCase(ConstantsActivityTimeline.TASK) && objTask.Document_Type__c != '' && objTask.Document_Type__c != 'Note' && objTask.Document_Type__c != 'Quick Note') ;
    }
    
    
    /*
     * Returns true if the Task is for a Log a Call"
     */       
    public static boolean isTaskLogACall(Task objTask, Set<String> setType)
    {
        return  (objTask.TaskSubType != NULL && setType.contains(ConstantsActivityTimeline.SET_TYPE_CALL) &&
                 objTask.TaskSubType.equalsIgnoreCase(ConstantsActivityTimeline.TASK_SUBTYPE_CALL) );
    }    
    
    
    /*
     * Returns true if the Type to search for include Events
     */   
    public static boolean isEventSetType(Set<String> setType)
    {
		return setType.contains(ConstantsActivityTimeline.SET_TYPE_EVENT);
    }    
    
    /*
     * Returns true if the Type to search for include Action Plans
     */   
    public static boolean isActionPlanSetType(Set<String> setType)
    {
		return setType.contains(ConstantsActivityTimeline.SET_TYPE_ACTION_PLAN);
    }    
    
    
    /*
     * Returns true if the Type to search for Emails
     */   
    public static boolean isEmailSetType(Set<String> setType)
    {
		return ( setType.contains(ConstantsActivityTimeline.SET_TYPE_EMAIL)
                  );
    }   

     /*
     * Returns true if the Type to search for MarketingEmails
     */    

    public static boolean isSSCEmailSetType(Set<String> setType)
    {
        return(setType.contains(ConstantsActivityTimeline.SET_TYPE_SSC_EMAIL));
    }
    
    /*
     * Returns true if the Type to search for SLM
     */   
    public static boolean isSlmSetType(Set<String> setType)
    {
		return setType.contains(ConstantsActivityTimeline.SET_TYPE_SLM);
    }
    
    /*
     * Returns true if the Type to search for Has Attachments"
     */   
    public static boolean isHasAttachmentSetType(Set<String> setType)
    {
		return setType.contains(ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT);
    }
    
    
    /*
     * Returns true if the dateFilter is last year or last 3 years
     */  
    public static Boolean isStartDateFilterForPastYears(String dateFilter) 
    {
        system.debug('***isStartDateFilterForPastYears ... dateFilter=>>' + dateFilter +'<<');
        
        String dateToFilter = '';
        if( dateFilter != null && dateFilter != '' && 
            (dateFilter == ConstantsActivityTimeline.LAST_YEAR || dateFilter == ConstantsActivityTimeline.LAST_THREE_YEARS))
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    
    
    /*
     * Returns Date Filter to be used in SOSL or SOQL filter criteria 
     */ 
    public static String getDateFilterQuery(Date activityDateFilter, Date startDate, Date endDate, Boolean isDueDate, 
                                            String dateFieldName, Boolean dayOnly)
    {
        system.debug('---> getDateFilterQuery() ... activityDateFilter=' + activityDateFilter);
        system.debug('---> getDateFilterQuery() ... startDate=' + startDate);
        system.debug('---> getDateFilterQuery() ... endDate=' + endDate);
        system.debug('---> getDateFilterQuery() ... isDueDate=' + isDueDate);
        system.debug('---> getDateFilterQuery() ... dateFieldName=' + dateFieldName);
        system.debug('---> getDateFilterQuery() ... dayOnly=' + dayOnly);
        
        String qq ='';
        
        String fieldName = null;
        if ( dateFieldName == 'ActivityDate' || dateFieldName == 'StartDate__c' || dateFieldName == 'Message_Sent_Date__c' )
        {
            fieldName  = dateFieldName;
        }
        else
        {
            fieldName = ' Day_Only(convertTimezone('+ dateFieldName +')) ';
        }
        

        if ( activityDateFilter != null )
        {
            qq = ' AND '+ dateFieldName +' = :activityDateFilter ';
        }
        else
        {
            
            if(isDueDate){
                if(endDate!=null && startDate!=null){
                    if(!dayOnly){
                        if(endDate==startDate){
                            qq = ' AND '+ dateFieldName +' = :endDate ';
                        }else{
                            qq = ' AND '+ dateFieldName +' >= :startDate AND ' + dateFieldName + ' <= :endDate ';
                        }   
                    }else {
                        if(endDate==startDate){
                            qq = ' AND '+ fieldName +' = :endDate ';
                        }else{
                            qq = ' AND '+ fieldName +' >= :startDate AND '+ fieldName +' <= :endDate ';
                        } 
                    }
                   
                }else{
                    if(dayOnly){
                        if(endDate!=null){
                            qq = ' AND '+ dateFieldName +' <= :endDate ';
                        }else{
                            qq = '  AND '+ dateFieldName +' >= :startDate ';
                        }
    
                    }else{
                        if(endDate!=null){
                            qq = ' AND '+ fieldName +' <= :endDate ';
                        }else{
                            qq = ' AND '+ fieldName +' >= :startDate ';
                        }
                    }
                   
                }
    
            }else{
                if(endDate!=null && startDate!=null){
                    if(endDate==startDate){
                        qq = ' AND '+ dateFieldName +' = :endDate ';
                    }else{
                        qq = ' AND '+ dateFieldName +' >= :startDate AND '+ dateFieldName +' <= :endDate ';
                    }
                    
                }else{
                    if(endDate!=null){
                        qq = ' AND '+ dateFieldName +' <= :endDate ';
                    }else{
                        qq = ' AND '+ dateFieldName +' >= :startDate ';
                    }
                }
            }
        }
        
        return qq;
    }
    
    
    
    /*
     * Returns the date field to be used in date range query
     */  
    private static String getDateFieldName(String defaultFieldName, String dateType)
    {
        String dateFieldForQuery = defaultFieldName;
        if (!String.isBlank(dateType) && dateType != 'dueDate') 
        {
            dateFieldForQuery = dateType;
        }
        
        return dateFieldForQuery;
        
    }
    

    /********************************************************
    *Method       -----  getDateFilterConverted
    *Date         -----  28/03/2022
    *Description  -----  This Method is used to get the filter value for Past Activites filter
    *return type ------- String type which containts the filter value
    *********************************************************/
    public static String getDateFilterConverted(String dateFilter) {
        String dateToFilter = '';
        if(ConstantsActivityTimeline.DATE_FILTER_MAP.containsKey(dateFilter)){
            return ConstantsActivityTimeline.DATE_FILTER_MAP.get(dateFilter);
        }
        else{
            return dateToFilter;
        }
    }
    
    
    
    //*******************************************************************************************
    //     CHILD CLASSES
    //*******************************************************************************************
    

    /*
     * Inner class used to store Email relation record Id's and Account name maps
     */  
	public class EmailIdSetObj
    {
        public Set<Id> emailMessageIdSet;
        public Map<Id, List<String>> emailAccountNameMap;
        
        public EmailIdSetObj(Set <Id> emailMessageIdSet, Map<Id,List<String>> emailAccountNameMap) 
        {
            this.emailMessageIdSet = emailMessageIdSet;
            this.emailAccountNameMap = emailAccountNameMap;
        }        
    }

    
    /*
     * Wrapper Class to store Email message related info
     */   
    public class EmailRelatedInfo
    {
        public List<EmailMessage> emailList;
        public Map<Id, List<String>> emailAccountNameMap;
        
        public EmailRelatedInfo(List<EmailMessage> emails, Map<Id, List<String>> emailAccountNameMap)
        {
            this.emailList = emails;
            this.emailAccountNameMap = emailAccountNameMap;
        }
    }
    

    /*
     * Wrapper Class to store Action Plan related info
     */   
    public class ActionPlanRelatedInfo
    {
        public List<ActionPlan__c> actionPlans;
        public Map<Id, Account> accountMap;
        
        public ActionPlanRelatedInfo(List<ActionPlan__c> actionPlans, Map<Id, Account> accountMap)
        {
            this.actionPlans = actionPlans;
            this.accountMap = accountMap;
        }
    }

    
    
    /*
     * Wrapper Class to store child Task related info
     */   
    public class TaskEventEmailRelatedInfo
    {
        public String taskEventRecordId;
        public boolean hasAttachments = false;
        public List<String> categories = new List<String>();
        
        public TaskEventEmailRelatedInfo(String recordId, boolean hasAttachments)
        {
            this.taskEventRecordId = recordId;
            this.hasAttachments = hasAttachments;
        }
        
        public String getTagString()
        {
            return String.join(categories, ',');
        }        
    }
        
       /* Methods to fetch salesforce records for Lazy load in activity timeline search Redesign*/

 public static List<Task> retrieveTasksLazyLoad(ActivityIdSetObj idSets, Date activityDateFilter, String range, String dateToFilter,
                                           String searchText, Boolean showOnlyPinned, 
                                           String dateType, Date startDate, Date endDate, String createdBy, 
                                           String assignedTo, Boolean isDueDate,Integer rows,Integer offset,string sortBy,string sortDirection)
    {
        system.debug('*** ActivityTimelineUtility.retrieveTasks() - START **');
        system.debug('222 activityDateFilter=' + activityDateFilter);
        system.debug('222 range=' + range);
        system.debug('222 dateToFilter=' + dateToFilter);
        system.debug('222 searchText=' + searchText);
        system.debug('222 dateType=' + dateType);
        system.debug('222 startDate=' + startDate);
        system.debug('222 endDate=' + endDate);
        system.debug('222 createdBy=' + createdBy);
        system.debug('222 assignedTo=' + assignedTo);
        
        //-----------------------------------------------------------------------------
        // STEP 1: Look for Task Relations based on the related Id's, used to find all related Tasks
        system.debug('STEP 1 - Query TaskRelation records');
        system.debug('222 idSets.contactIdSetTask=' + idSets.contactIdSetTask);
        system.debug('222 idSets.WhatIdSet=' + idSets.WhatIdSet);
        
        // Tasks that we want to query for
        Set<Id> taskIDSet = populateTaskIdSet(idSets);        
        
        //-----------------------------------------------------------------------------
        // STEP 3: Query for Tasks (prepare query)
        system.debug('STEP 3 - Query TASK records ... ');
        Set<Id> whatIdSetTask = idSets.whatIdSetTask;
        system.debug('333 - whatIdSetTask=' + whatIdSetTask);

        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();
        
        
        String dateFieldForQuery = getDateFieldName('ActivityDate', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.TASK_INITIAL_FILTERS_REDESIGN, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('333 - filterCriteria(After Adding More Criteria)=' + filterCriteria);

        system.debug('333 - dateFieldForQuery=' + dateFieldForQuery);

        if ( !String.isBlank(searchText) )
        {
            system.debug('333 - SEARCH USING SOSL to isolate the Task IDs first');

            // For Past Activity Filter (Picklist Option Selected)
            if( !String.isBlank(dateToFilter) )
            {
                system.debug('333b - adding (' + dateToFilter + ') to filterCriteria ... ');
                filterCriteria = filterCriteria + ' AND ActivityDate = ' + dateToFilter  + ' ';
            }
            system.debug('333b - filterCriteria(FINAL)=' + filterCriteria);
 			/*String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING Task (Id, Subject, Status WHERE  ';
            String searchquery = 'FIND \'' + searchText + '\' IN ALL FIELDS RETURNING Task (Id, Subject, Status WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('333 - searchquery=' + searchquery);
            List<Task> searchResults = (List<Task>)search.query(searchquery)[0];            
            system.debug('333 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                system.debug('333 - Loop through searchResults ... ');
                for ( Task currTask: searchResults)
                {
                    system.debug('333a -> currTask.Id=' + currTask.Id);
                    system.debug('333a -> currTask.Subject=' + currTask.Subject);
                    system.debug('333a -> currTask.Status=' + currTask.Status);
                    searchResultsIdSet.add(currTask.Id);
                }
            }*/
        }
        
       // system.debug('333 - searchResultsIdSet=' + searchResultsIdSet);
       // system.debug('333 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        List<Task> taskList = new List<Task>();
        List<Task> finalTaskList = new List<Task>();
        //List<Task> nonRectaskList = new List<Task>();
        
        String taskQuery = 'SELECT ' + ConstantsActivityTimeline.TASK_QUERY_FIELDS + ', (SELECT id FROM TaskRelations WHERE IsWhat = FALSE) ';        
        taskQuery += ' FROM Task WHERE ';

/*if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            system.debug('333 DEBUG 111aaaaa');
            String searchPhraseString = '%'+searchText+'%';
            taskQuery += ' (Id IN:searchResultsIdSet OR ';
            //taskQuery += '  (Subject LIKE: searchPhraseString AND ' + filterCriteria + ') )';
            taskQuery += filterCriteria +')';
        }
        else if ( String.isBlank(searchText) )
        {
            system.debug('333 DEBUG 111bbbbb');
            taskQuery += filterCriteria;
        }*/
         taskQuery += filterCriteria;
       
        if ( range == ConstantsActivityTimeline.DATE_RANGE_UPCOMING )
        {
            system.debug('333 DEBUG UPCOMING ....');
            taskQuery += ' AND IsClosed=false AND ( ActivityDate > TODAY OR status != \'COMP\') ';    
        }
        else if ( range == ConstantsActivityTimeline.DATE_RANGE_PAST )
        {
            system.debug('333 DEBUG PAST ... ');
            taskQuery += ' AND IsClosed=true ';    
            
           
        }

         // For Filter Range 
         if(String.isNotBlank(dateToFilter)){
                
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                taskQuery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND ActivityDate >  TODAY ) )  ' ;                                   
            }
            else
            {
                taskQuery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR ActivityDate = THIS_YEAR )  ' ;                                   
            }
        }
        
        if(showOnlyPinned)
        {
            taskQuery = taskQuery + ' AND Is_Pinned__c=TRUE ';
        }
        
        taskQuery += ' AND ( IsArchived=TRUE OR IsDeleted=FALSE ) ';
        
       
        taskQuery += ' ORDER BY ActivityDate ' +sortDirection;
        
        system.debug('rowsss------------->'+rows);
          system.debug('offset------------->'+offset);
        //taskQuery += ' LIMIT '+rows+' OFFSET '+offset;
        
        system.debug('333 - taskQuery=' + taskQuery);
        taskList = Database.query(taskQuery);
        system.debug('333 - taskList.size()=' + taskList.size());
        List<String> fieldNames = SOQLSearchFieldNames(ConstantsActivityTimeline.TASK); 
         
        //adding the logic to perfrom search on both subject and description field
        if (!String.isBlank(searchText) && !taskList.isEmpty()) {
            String lowerSearch = searchText.toLowerCase();
            List<Task> filteredTaskList = new List<Task>();
            for (Task t : taskList) {
                for(String fields: fieldNames){
                    if (t.get(fields) != null )
                    {
                        string getField= (string) t.get(fields);
                        if(getField.toLowerCase().contains(lowerSearch) && !filteredTaskList.contains(t)){
                            filteredTaskList.add(t);
                        }
                        
                    }               
                }
            }
            taskList = filteredTaskList;
        }

    // Logic for recurring task filtering  -- removed

/*
    
      for (Task taskObj: taskList){
           
          if(taskObj.IsRecurrence == False)
          {
             if(taskObj.RecurrenceActivityId == null)
             {
              finalTaskList.add(taskObj);
             }
             
             else
             {
                if(taskObj.Status == 'Completed') 
                {
                   finalTaskList.add(taskObj);
                }
             }
          }
           
         if(taskObj.IsRecurrence == True)
          {
              system.debug('getting recur task parent');
              finalTaskList.add(taskObj);
          }

       }
*/
       // only include the valid child tasks and completed parent task(all child tasks are completed)
    
       Map<String,Task> taskMap = new Map<String,Task>();
        for (Task taskObj: taskList){
            if(taskObj.IsRecurrence != True){
            finalTaskList.add(taskObj);
            }else{
                system.debug('recurring taskObj='+taskObj);
               // recurringTaskId.add(taskObj.Id);
                taskMap.put(String.valueOf(taskObj.Id),taskObj);
            }
        }
        system.debug('final task list---------->'+finalTaskList.size());

        // aggregate result for recurring task child task status check
        Map<String,Integer> recurringCountMap = new Map<String,Integer>();
        Map<String,Integer> recurringCompleteCountMap = new Map<String,Integer>();
        if(taskMap.size()>0) {
            for(AggregateResult ar : [select count(id) childRecord, RecurrenceActivityId  from task  where IsRecurrence = false and RecurrenceActivityId!=null and RecurrenceActivityId in : taskMap.keyset()  GROUP BY RecurrenceActivityId ]){   
                recurringCountMap.put( String.valueOf(ar.get('RecurrenceActivityId')), Integer.valueOf(ar.get('childRecord')));  
            }

            for(AggregateResult ar1 : [select count(id) childRecord, RecurrenceActivityId  from task  where IsRecurrence = false and RecurrenceActivityId!=null and Status ='COMP' and RecurrenceActivityId in : taskMap.keyset()  GROUP BY RecurrenceActivityId ]){   
                recurringCompleteCountMap.put( String.valueOf(ar1.get('RecurrenceActivityId')), Integer.valueOf(ar1.get('childRecord')));  
            }
        }
        system.debug('recurringCountMap ='+recurringCountMap);
        system.debug('recurringCompleteCountMap ='+recurringCompleteCountMap);
        for (String key : recurringCompleteCountMap.keyset()){
            if(recurringCompleteCountMap.get(key)==recurringCountMap.get(key)){
                finalTaskList.add(taskMap.get(key));
                system.debug('recurring complete parent task='+taskMap.get(key));
            }
        }

         system.debug('after recurring complete logic final task list---------->'+finalTaskList.size());
        return finalTaskList;
    }
    
    
    /*
     * Query for Events
     */  
    public static List<Event> retrieveEventsLazyLoad(ActivityIdSetObj idSets, Date activityDateFilter, String range, String dateToFilter,
                                      		String searchText, Boolean showOnlyPinned, 
                                           	String dateType, Date startDate, Date endDate, String createdBy, 
                                           	String assignedTo, Boolean isDueDate,Integer rows,Integer offset,string sortBy,string sortDirection)
    {
        system.debug('*** ActivityTimelineUtility.retrieveEvents() - START **');
        system.debug('222 activityDateFilter=' + activityDateFilter);
        system.debug('222 range=' + range);
        system.debug('222 dateToFilter=' + dateToFilter);
        system.debug('222 searchText=' + searchText);
        system.debug('222 dateType=' + dateType);
        system.debug('222 startDate=' + startDate);
        system.debug('222 endDate=' + endDate);
        system.debug('222 createdBy=' + createdBy);
        system.debug('222 assignedTo=' + assignedTo);
        
        Set<Id> eventIDSet = populateEventIdSet(idSets);
        system.debug('444 - eventIDSet=' + eventIDSet);
        
        Set<Id> whatIdSetEvent = idSets.whatIdSetEvent;
        system.debug('444 - whatIdSetEvent=' + whatIdSetEvent);

        Set<Id> contactIdSet = idSets.contactIdSet;
        system.debug('444 - contactIdSet=' + contactIdSet);
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();

        String dateFieldForQuery = getDateFieldName('ActivityDate', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.EVENT_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('444 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('444 - SEARCH USING SOSL to isolate the Event IDs first');

            // For Past Activity Filter (Picklist Option Selected)
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND ActivityDate = ' + dateToFilter + ' ';
            }
            
            /*String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('444 - filterCriteria(FINAL111)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING Event (Id  WHERE  ';
            searchquery += filterCriteria+') LIMIT 1999';
            system.debug('444 - searchquery=' + searchquery);
            List<Event> searchResults = (List<Event>)search.query(searchquery)[0];
            system.debug('444 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( Event currEvent: searchResults)
                {
                    searchResultsIdSet.add(currEvent.Id);
                }
            }*/
        }
        
       // system.debug('444 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        DateTime objDateTimeNow = System.now();
        String ARMEventTypeStr = WMC_Constants.ANNUAL_REVIEW_MEETING;
        String completeStatusStr = WMC_Constants.STATUS_VALUE_COMPLETED;
        String eventQuery = 'SELECT ' + ConstantsActivityTimeline.EVENT_QUERY_FIELDS + ', (SELECT id FROM EventRelations WHERE IsWhat = FALSE)';
        eventQuery +=' FROM Event WHERE  ';
        
      /*  if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            eventQuery += ' (Id IN:searchResultsIdSet OR ';
             += '  (Subject LIKE: searchPhraseString AND ' + filterCriteria + ') )';
            eventQuery += filterCriteria + ' )';
        }
        else
        {
            eventQuery += filterCriteria;
        }   */     
        
         eventQuery += filterCriteria;
        if ( range == ConstantsActivityTimeline.DATE_RANGE_UPCOMING )
        {
            eventQuery += ' AND ((EndDateTime > :objDateTimeNow AND ';
            eventQuery += '(Type != :ARMEventTypeStr OR Auto_Completion__c = TRUE)) OR ';
            eventQuery += ' ((Status__c !=:completeStatusStr OR Is_Attested__c = FALSE) AND ';
            eventQuery += 'Type = :ARMEventTypeStr AND Auto_Completion__c = FALSE)) ';
        }
        else if ( range == ConstantsActivityTimeline.DATE_RANGE_PAST )
        {
            eventQuery += ' AND ((EndDateTime < :objDateTimeNow AND ';
            eventQuery += ' (Type != :ARMEventTypeStr OR Auto_Completion__c = TRUE)) OR ';
            eventQuery += ' (Status__c = :completeStatusStr AND Is_Attested__c = TRUE AND ';
            eventQuery += ' Type = :WMC_Constants.ARMEventTypeStr AND Auto_Completion__c = FALSE))';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                eventquery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND ActivityDate >  TODAY ) )  ' ;                                   
            }
            else
            {
                eventquery +=  ' AND  ( ActivityDate = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR ActivityDate = THIS_YEAR )  ' ;                                   
            }
        }            
        
        if(showOnlyPinned){
            eventQuery += ' AND IS_Pinned__c = TRUE ';
        }
        
        eventquery += ' AND ( IsArchived=TRUE OR IsDeleted=FALSE ) ';
        
        eventQuery +=  ' ORDER BY EndDateTime ' +sortDirection;
        //eventQuery += ' LIMIT '+rows+' OFFSET '+offset;
         
        system.debug('444 - eventQuery=' + eventQuery);
        List<Event> eventList = Database.query(eventQuery);
        Map<ID, Event> eventMap = new Map<ID, Event> ();
         if (eventList != null && eventList.size() > 0 )
            {
                for ( Event currEvent: eventList)
                {
                    eventMap.put(currEvent.Id, currEvent);
                }
            }
        List<String> fieldNames =SOQLSearchFieldNames(ConstantsActivityTimeline.EVENT);   
        
        if(!String.isBlank(searchText) && !eventList.isEmpty()){
          eventMap.clear();
          String searchLowerCase = searchText.toLowerCase();
         for (Event evt:eventList){                        
          for(String fields: fieldNames){
                    if (evt.get(fields) != null )
                    {
                        string getField= (string) evt.get(fields);
                        if(getField.toLowerCase().contains(searchLowerCase)){
                              eventMap.put(evt.ID, evt);
                        }
                        
                    }               
                }            
        }
        
    }
        system.debug('444 - eventList.size()=' + eventList.size() );              
        
        return eventMap.values();
    }
    
    
    /*
     * Query for Action Plans
     */  
    public static ActionPlanRelatedInfo retrieveActionPlansLazyLoad(ActivityIdSetObj idSets, Date activityDateFilter, String range, 
                                                         	String dateToFilter, String searchText, boolean showOnlyPinned, 
                                                            String dateType, Date startDate, Date endDate, String createdBy, 
                                                            String assignedTo, Boolean isDueDate,Integer rows,Integer offset,string sortBy,string sortDirection)
    {
        system.debug('555c Action Plans ... ');
        Set<Id> accountIdSetActionPlan = idSets.accountIdSetActionPlan;
        Set<Id> whatIdSetActionPlan = idSets.whatIdSetActionPlan;
        Set<Id> whatIdSet = idSets.whatIdSet;
        system.debug('555c accountIdSetActionPlan=' + accountIdSetActionPlan);
        system.debug('555c whatIdSetActionPlan=' + whatIdSetActionPlan);
        system.debug('555c whatIdSet=' + whatIdSet);
        
        Map<Id, Account> accountMap = getAccountMap(idSets.recordId, idSets);
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();

        String dateFieldForQuery = getDateFieldName('StartDate__c', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.ACTION_PLAN_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('555 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('555 - SEARCH USING SOSL to isolate the Record IDs for Action Plans first');
            
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND StartDate__c = ' + dateToFilter + ' ';
            }
            /*String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('555 - filterCriteria(FINAL)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING ActionPlan__c (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('555 - searchquery=' + searchquery);
            List<ActionPlan__c> searchResults = (List<ActionPlan__c>)search.query(searchquery)[0];
            system.debug('555 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( ActionPlan__c currAP: searchResults)
                {
                    searchResultsIdSet.add(currAP.Id);
                }
            }*/
        }
        
        //system.debug('444 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        String queryAP = 'SELECT ' + ConstantsActivityTimeline.ACTION_PLAN_QUERY_FIELDS;
        queryAP +=' FROM ActionPlan__c WHERE ';
        
       /* if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            queryAP += ' (Id IN:searchResultsIdSet OR ';
            queryAP += '  (Name LIKE: searchPhraseString AND ' + filterCriteria + ') )';           
        }
        else
        {
            queryAP += filterCriteria;
        }  */      
        queryAP += filterCriteria;
        
        if ( range == ConstantsActivityTimeline.DATE_RANGE_UPCOMING )
        {
            queryAP +=' And Status__c != \'' + WMC_Constants.STATUS_COMPLETED + '\' ';
        }
        else if ( range == ConstantsActivityTimeline.DATE_RANGE_PAST )
        {
            queryAP +=' And Status__c = \'' + WMC_Constants.STATUS_COMPLETED + '\' ';
        }
        
        if( activityDateFilter != null ){
            queryAP += ' And StartDate__c =:activityDateFilter';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                queryAP +=  ' AND  ( StartDate__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( StartDate__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND StartDate__c >  TODAY ) )  ' ;                                   
            }
            else
            {
                queryAP +=  ' AND  ( StartDate__c = '+ String.escapeSingleQuotes(dateToFilter) + ' OR StartDate__c = THIS_YEAR) ' ;
            }            
        }
        
        if(showOnlyPinned){
            queryAP += ' AND Is_Pinned__c = TRUE ';
        }
        queryAP += ' ORDER BY StartDate__c ' +sortDirection;
        //queryAP += ' LIMIT '+rows+' OFFSET '+offset;
        
        system.debug('555c query(ActionPlans)=' + queryAP);
        
        List<ActionPlan__c> actionPlans = Database.query(queryAP);
        system.debug('555c actionPlans.size()=' + actionPlans.size());
        
         Map<ID, ActionPlan__c> actionPlanMap = new Map<ID, ActionPlan__c> ();
         if (actionPlans != null && actionPlans.size() > 0 )
            {
                for ( ActionPlan__c currActionPlan: actionPlans)
                {
                    actionPlanMap.put(currActionPlan.Id, currActionPlan);
                }
            }
         List<String> fieldNames =SOQLSearchFieldNames(ConstantsActivityTimeline.ACTION_PLAN);                  

        if(!String.isBlank(searchText) && !actionPlans.isEmpty()){
          actionPlanMap.clear();
          String searchLowerCase = searchText.toLowerCase();
         for (ActionPlan__c evt:actionPlans){                        
         for(String fields: fieldNames){
                    if (evt.get(fields) != null )
                    {
                        string getField= (string) evt.get(fields);                                               
                        if(getField.toLowerCase().contains(searchLowerCase)){
                              actionPlanMap.put(evt.ID, evt);
                        }
                        
                    }               
                }           
        }
        
    }          

		ActionPlanRelatedInfo apInfo = new ActionPlanRelatedInfo(actionPlanMap.values(), accountMap);
        
        return apInfo;
    }
    
    
    /*
     * Query for IER records (Marketing Emails)
     */  
    public static List<et4ae5__IndividualEmailResult__c> retrieveIERsLazyLoad(ActivityIdSetObj idSets, Date activityDateFilter, String range, 
                                                                      String dateToFilter, String searchText, String profileId, Boolean showOnlyPinned, 
                                                                      String dateType, Date startDate, Date endDate, String createdBy, 
                                                                      String assignedTo, Boolean isDueDate,Integer rows,Integer offset,string sortBy,string sortDirection)
    {
        system.debug('*** retrieveIERs() - GO!!! ***');
        List<et4ae5__IndividualEmailResult__c> individualEmailResults = new List<et4ae5__IndividualEmailResult__c>();
        
        system.debug('666 idSets.isPersonAccount=' + idSets.isPersonAccount);

        Set<Id> contactIdSet = idSets.contactIdSet;
        system.debug('666 - contactIdSet=' + contactIdSet);
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();
        
        String dateFieldForQuery = getDateFieldName('et4ae5__DateSent__c', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.IER_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('666 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('666 - SEARCH USING SOSL to isolate the IER Record IDs first');
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND et4ae5__DateSent__c = ' + dateToFilter + ' ';
            }
            
            /*String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('666 - filterCriteria(FINAL)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING et4ae5__IndividualEmailResult__c (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('666 - searchquery=' + searchquery);
            List<et4ae5__IndividualEmailResult__c> searchResults = (List<et4ae5__IndividualEmailResult__c>)search.query(searchquery)[0];
            system.debug('666 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( et4ae5__IndividualEmailResult__c ier: searchResults)
                {
                    searchResultsIdSet.add(ier.Id);
                }
            }*/
        }
        
        //system.debug('666 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        String queryIER = 'SELECT '+ ConstantsActivityTimeline.IER_QUERY_FIELDS + ' FROM et4ae5__IndividualEmailResult__c WHERE ';
        
       /* if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            queryIER += ' (Id IN:searchResultsIdSet OR ';
            queryIER += '  (et4ae5__SubjectLine__c LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else
        {
            queryIER += filterCriteria;
        }   */ 
        queryIER += filterCriteria;
        
        if(activityDateFilter!= null){
            queryIER +=  ' AND et4ae5__DateSent__c =:activityDateFilter';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                queryIER +=  ' AND  ( et4ae5__DateSent__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( et4ae5__DateSent__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND et4ae5__DateSent__c >  TODAY ) )  ' ;                                   
                
            }
            else
            {
                queryIER +=  ' AND  ( et4ae5__DateSent__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR et4ae5__DateSent__c = THIS_YEAR ) ' ;                                   
            }            
        }
        
        if(showOnlyPinned){
            queryIER += ' AND Is_Pinned__c = TRUE ';
        }
        queryIER += ' ORDER BY et4ae5__DateSent__c '+ sortDirection;
        // queryIER +=' LIMIT '+rows+' OFFSET '+offset;
        system.debug('666 - queryIER=' + queryIER);
        individualEmailResults = Database.query(queryIER);
        
        Map<ID, et4ae5__IndividualEmailResult__c> individualEmailResultsMap = new Map<ID, et4ae5__IndividualEmailResult__c> ();
         if (individualEmailResults != null && individualEmailResults.size() > 0 )
            {
                for ( et4ae5__IndividualEmailResult__c currIER: individualEmailResults)
                {
                    individualEmailResultsMap.put(currIER.Id, currIER);
                }
            }
          List<String> fieldNames =SOQLSearchFieldNames(ConstantsActivityTimeline.IER);
        
        if(!String.isBlank(searchText) && !individualEmailResults.isEmpty()){
          individualEmailResultsMap.clear();
          String searchLowerCase = searchText.toLowerCase();
         for (et4ae5__IndividualEmailResult__c evt:individualEmailResults){                        
        for(String fields: fieldNames){
                    if (evt.get(fields) != null )
                    {
                        string getField= (string) evt.get(fields);
                        if(getField.toLowerCase().contains(searchLowerCase)){
                              individualEmailResultsMap.put(evt.ID, evt);
                        }
                        
                    }               
                }            
        }
        
    }
        
        return individualEmailResultsMap.values();
    }    
    
    
    
    /*
     * Query for EmailMessage records (Salesforce Emails)
     */  
    public static EmailRelatedInfo retrieveEmailsLazyLoad(ActivityIdSetObj idSets, Date activityDateFilter, String range, 
                                                  String dateToFilter, String searchText, String profileId, Boolean showOnlyPinned, 
                                                  String dateType, Date startDate, Date endDate, String createdBy, 
                                                  String assignedTo, Boolean isDueDate,Integer rows,Integer offset,string sortBy,string sortDirection)
    {
        system.debug('777 SALESFORCE EMAILS .... Loop through them and prepare wrappers');
        Set <Id> emailMessageIdSet = new Set<Id>();
        Map<Id, List<String>> emailAccountNameMap = new Map<Id,List<String>>();
        
        // Get the relationships
        EmailIdSetObj emailObj = getEmailIdSetInfo(profileId, idSets);
        if ( emailObj.emailMessageIdSet != null && !emailObj.emailMessageIdSet.isEmpty()) {
            emailMessageIdSet = emailObj.emailMessageIdSet;
        }
        if ( emailObj.emailAccountNameMap != null && !emailObj.emailAccountNameMap.isEmpty()) {
            emailAccountNameMap = emailObj.emailAccountNameMap;
        }        
        
        system.debug('777 - idSets.contactIdSet.size()=' + idSets.contactIdSet.size() );
        system.debug('777 - idSets.whatIdSet.size()=' + idSets.whatIdSet.size() );
        system.debug('777 - profileId=' + profileId );
        
        system.debug('777 emailAccountNameMap.size()=' + emailAccountNameMap.size() );
        system.debug('777 emailMessageIdSet.size()=' + emailMessageIdSet.size() );
        
        Set<Id> contactIdSetEmail = idSets.contactIdSet;
        Set<Id> whatIdSet = idSets.whatIdSet;
        system.debug('777 contactIdSetEmail.size()=' + contactIdSetEmail.size() );
        system.debug('777 dateToFilter=' + dateToFilter );
        
        
        // Perform a Search using SOSL (if searchText was provided)
        Set<Id> searchResultsIdSet = new Set<Id>();

        String dateFieldForQuery = getDateFieldName('Message_Sent_Date__c', dateType);
        String filterCriteria = getFilterCriteria(ConstantsActivityTimeline.EMAIL_INITIAL_FILTERS, activityDateFilter, 
                                                  startDate, endDate, isDueDate, dateFieldForQuery, assignedTo, createdBy);
        system.debug('777 - filterCriteria(After Adding More Criteria)=' + filterCriteria);
        
        if ( !String.isBlank(searchText) )
        {
            system.debug('777 - SEARCH USING SOSL to isolate the EmailMessage IDs first');
            if( !String.isBlank(dateToFilter) ){
                filterCriteria = filterCriteria + ' AND Message_Sent_Date__c = ' + dateToFilter + ' ';
            }
            /*String SOSLsearchResults = ActivityTimelineUtility.handleSOSLSpecialCharacters(searchText);
            system.debug('777 - filterCriteria(FINAL)=' + filterCriteria);
            String searchquery = 'FIND {' + SOSLsearchResults + '} IN ALL FIELDS RETURNING EmailMessage (Id  WHERE  ';
            searchquery += filterCriteria +') LIMIT 1999';
            system.debug('777 - searchquery=' + searchquery);
            List<EmailMessage> searchResults = (List<EmailMessage>)search.query(searchquery)[0];
            system.debug('777 - searchResults.size()=' + searchResults.size());
            if (searchResults != null && searchResults.size() > 0 )
            {
                for ( EmailMessage currEmail: searchResults)
                {
                    searchResultsIdSet.add(currEmail.Id);
                }
            }*/
        }
        
        //system.debug('777 - searchResultsIdSet.size()=' + searchResultsIdSet.size());
        
        String queryEmail = 'SELECT ' + ConstantsActivityTimeline.EMAIL_QUERY_FIELDS + ', ';
        queryEmail += '(SELECT id, RelationId, Relation.Name, RelationType FROM EmailMessageRelations ';
        queryEmail += 'WHERE RelationType = \'ToAddress\'  AND RelationId != NULL) ';
        queryEmail += 'FROM EmailMessage WHERE ';
        
     /*   if ( !String.isBlank(searchText) && searchResultsIdSet != null && searchResultsIdSet.size() >= 0 )
        {
            String searchPhraseString = '%'+searchText+'%';
            queryEmail += ' (Id IN:searchResultsIdSet OR ';
            queryEmail += '  (Subject LIKE: searchPhraseString AND ' + filterCriteria + ') )';
        }
        else
        {
            queryEmail += filterCriteria;
        } */       
         queryEmail += filterCriteria;
        
        if(activityDateFilter!=null){
            queryEmail += ' And (Message_Sent_Date__c =:activityDateFilter OR MessageDate=:activityDateFilter ) ';
        }
        
        if(String.isNotBlank(dateToFilter))
        {
            system.debug('777 AAAAAA=' );
            if ( !isStartDateFilterForPastYears(dateToFilter) )
            {
                system.debug('777 BBBBBBBB' );
                queryEmail +=  ' AND  ( Message_Sent_Date__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    +' OR  ( Message_Sent_Date__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  AND Message_Sent_Date__c >  TODAY ) )  ' ;                                   
                
            }
            else
            {
                system.debug('777 CCCCCCCCCC - ' + String.escapeSingleQuotes(dateToFilter) );
                queryEmail +=  ' AND  ( Message_Sent_Date__c = '+ String.escapeSingleQuotes(dateToFilter) 
                    + '  OR Message_Sent_Date__c = THIS_YEAR )  ' ;                                   
            }
        }            
        
        if(showOnlyPinned){
            queryEmail += ' AND Is_Pinned__c = TRUE ';
        }
        queryEmail += ' ORDER BY MessageDate ' + sortDirection;
        system.debug('777 queryEmail(EMAIL)=' + queryEmail );
        
        List<EmailMessage> emailList = Database.query(queryEmail);
        system.debug('777 emailList.size()=' + emailList.size() );
        
        
        
        Map<ID, EmailMessage> emailListMap = new Map<ID, EmailMessage> ();
         if (emailList != null && emailList.size() > 0 )
            {
                for ( EmailMessage currEmail: emailList)
                {
                    emailListMap.put(currEmail.Id, currEmail);
                }
            }
        List<String> fieldNames =SOQLSearchFieldNames(ConstantsActivityTimeline.EMAIL);  
        
        if(!String.isBlank(searchText) && !emailList.isEmpty()){
          emailListMap.clear();
             String searchLowerCase = searchText.toLowerCase();
         for (EmailMessage evt:emailList){                        
        for(String fields: fieldNames){
                    if (evt.get(fields) != null )
                    {
                        string getField= (string) evt.get(fields);
                        if(getField.toLowerCase().contains(searchLowerCase)){
                              emailListMap.put(evt.ID, evt);
                        }
                        
                    }               
                }            
        }
        
    }
        
        
        return new EmailRelatedInfo(emailListMap.values(), emailAccountNameMap);
    }

     /********************************************************
    *Method       -----  getHouseholdMembers
    *Date         -----  07/07/2025
    *Description  -----  Method to get the Household primary member contact Id and task record types
    *return type ------- ActivityButtonWrapper
    *JIRA ID ------ WMCSFH2 - 6606
    *********************************************************/
    @AuraEnabled
    public static ActivityButtonWrapper getHouseholdMembers(Id accountRecordId){
        ActivityButtonWrapper wrapper = new ActivityButtonWrapper();
        Id contactIdRecord;
        Id accountRecordTypeId = [SELECT Id, RecordTypeId FROM Account WHERE Id =: accountRecordId LIMIT 1].RecordTypeId;

        wrapper.documentRecordTypeId= ConstantsActivityTimeline.DOC_RECORD_TYPE_ID;
        wrapper.taskRecordTypeId = ConstantsActivityTimeline.TASK_RECORD_TYPE_ID;

        if(accountRecordId != NULL && accountRecordTypeId == AccountService.householdRecordTypeId){
           
            for(AccountContactRelation acrRecord : [SELECT Id, ContactId FROM AccountContactRelation WHERE AccountId =: accountRecordId AND FinServ__PrimaryGroup__c = TRUE AND IsActive = TRUE AND (Roles =: WMC_Constants.PRIMARY_CONTACT OR Roles =: WMC_Constants.PRIMARY_CONTACT_LABEL) WITH SECURITY_ENFORCED LIMIT 1]){
                wrapper.primaryContactRecordId = acrRecord.ContactId;
            }
          }
             return wrapper;

    }

    
        
/*Methods for Lazy load End*/   
    /*
     * Wrapper class to store different record Id sets
     */  
    public class ActivityIdSetObj
    {
        public String recordId;
        public boolean isAccount = false;
        public boolean isPersonAccount = false;
        
        public Set<Id> emailMessageIdSet = new Set<Id>();
        public Set<Id> whatIdSet = new Set<Id>();
        public Set<Id> whatIdSetEvent = new Set<Id>();
        public Set<Id> whatIdSetTask = new Set<Id>();
        public Set<Id> whatIdSetActionPlan = new Set<Id>();
        public Set<Id> whatIdSetFinancialAccount = new Set<Id>();
        public Set<Id> contactIdSet = new Set<Id>();
        public Set<Id> contactIdSetEvent = new Set<Id>();
        public Set<Id> contactIdSetTask = new Set <Id>();
        public Set<Id> accountIdSetActionPlan = new Set <Id>();
        
        
        public ActivityIdSetObj(Id recordId)
        {
            this.recordId = recordId;
            this.whatIdSet.add(recordId);
            this.whatIdSetEvent.add(recordId);
            this.whatIdSetTask.add(recordId);
            this.whatIdSetActionPlan.add(recordId);
            this.whatIdSetfinancialAccount.add(recordId);
        }
    }
    
      /*
     * handleSOSLSpecialCharacters: Helper method to add escape for Reserved characters in the  search Keyword
     */  
    
    private static String handleSOSLSpecialCharacters(String searchTerm){   
     String results = null;           
    	 if(searchTerm!= null){
        	 results = searchTerm;                     
          	// Escaping backslash first 
         	 results = results.replace('\\','\\\\');           
             // Escaping other special characters
         			for(string str2:specialCharMap){
            		 String escapeChar = '\\';            
            		 results = results.replace(str2,escapeChar+str2);            
         			}
         system.debug(results);  
         return results;         
      	}   
     return results;
    }  
    
    
       /*
     * SOQLSearchFieldNames: Helper method to return the fields to be searched for each object in search functionality
     */  
    
    private static List<String> SOQLSearchFieldNames(String SobjectName){   
      List<String> fieldNames = new List<String>();
        for (ActivityTimelineSearch_SOQL_Fields__mdt fields: SOQLSearchFieldList){
            if( fields.DeveloperName.toLowerCase() == SobjectName){
                fieldNames=fields.SOQL_Fields__c.split(',');
            }
        } 
		return fieldNames;
    }  
 
    /*
     * Wrapper class to store different record type Ids
     */

    public class ActivityButtonWrapper
    {
        @AuraEnabled
        public Id primaryContactRecordId;

       @AuraEnabled
        public String documentRecordTypeId;
        
        @AuraEnabled
        public String taskRecordTypeId;

    }

}