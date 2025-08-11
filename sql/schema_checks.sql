-- rows check
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'installments', COUNT(*) FROM installments
UNION ALL
SELECT 'merchants', COUNT(*) FROM merchants;

-- date ranges check
SELECT MIN(registration_date) AS min_date, MAX(registration_date) AS max_date FROM users;
SELECT MIN(transaction_date) AS min_date, MAX(transaction_date) AS max_date FROM transactions;
SELECT MIN(scheduled_date) AS min_date, MAX(scheduled_date) AS max_date FROM installments;

-- null values check
SELECT COUNT(*) AS null_user_id_in_tx FROM transactions WHERE user_id IS NULL;
SELECT COUNT(*) AS null_tx_id_in_inst FROM installments WHERE transaction_id IS NULL;
