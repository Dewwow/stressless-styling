#!/usr/bin/env python3
"""
Build SQLite database from CSV files for CumulusCI data loading.
Run this script after modifying any CSV files to update the database.

Usage: python datasets/sample/build_database.py
"""
import sqlite3
import csv
import os

def build_database():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    db_path = os.path.join(script_dir, 'sample.db')

    # Remove existing database
    if os.path.exists(db_path):
        os.remove(db_path)
        print(f"Removed existing database: {db_path}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Load order matters for foreign key relationships
    csv_files = [
        'Service_Category__c',
        'Service__c',
        'Contact',
        'Stylist__c',
        'Stylist_Service__c',
        'Stylist_Availability__c',
        'Preferences__c',
        'Appointment__c',
        'Appointment_Service__c'
    ]

    total_rows = 0

    for table_name in csv_files:
        csv_path = os.path.join(script_dir, f'{table_name}.csv')
        if not os.path.exists(csv_path):
            print(f"Warning: {csv_path} not found, skipping")
            continue

        with open(csv_path, 'r') as f:
            reader = csv.reader(f)
            headers = next(reader)

            # Create table with Id as PRIMARY KEY (required for SQLAlchemy automap)
            columns = []
            for h in headers:
                if h == 'Id':
                    columns.append(f'"{h}" TEXT PRIMARY KEY')
                else:
                    columns.append(f'"{h}" TEXT')
            columns_str = ', '.join(columns)
            cursor.execute(f'CREATE TABLE IF NOT EXISTS "{table_name}" ({columns_str})')

            # Insert data
            rows = list(reader)
            placeholders = ', '.join(['?' for _ in headers])
            for row in rows:
                cursor.execute(f'INSERT INTO "{table_name}" VALUES ({placeholders})', row)

            total_rows += len(rows)
            print(f"  {table_name}: {len(rows)} rows")

    conn.commit()
    conn.close()

    print(f"\nDatabase created: {db_path}")
    print(f"Total rows: {total_rows}")

if __name__ == '__main__':
    build_database()
