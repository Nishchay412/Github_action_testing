public with sharing class AccountService {

    // Create a single Account and return the inserted record
    public static Account createAccount(String name, String phone) {
        // Basic guard so we don't insert empty names
        if (String.isBlank(name)) {
            // In a real project you might throw a custom exception;
            // for now we just return null to keep it simple.
            return null;
        }

        Account acc = new Account(
            Name  = name,
            Phone = phone
        );

        insert acc;
        return acc;
    }

    // Count how many Accounts have a matching phone number
    public static Integer countAccountsByPhone(String phone) {
        Integer cnt = [
            SELECT COUNT()
            FROM Account
            WHERE Phone = :phone
        ];
        return cnt;
    }
}