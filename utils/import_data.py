import os
from sqlalchemy import create_engine, text

connection_url = (
    "mssql+pyodbc://@localhost\\SQLEXPRESS/furniture_shop?"
    "driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
)

engine = create_engine(connection_url)

sql_files = [
    "Category.sql", "PartsSupplier.sql", "Shippers.sql", "Customers.sql", "Payments.sql",
    "Addresses.sql", "Parts.sql", "Products.sql", "Orders.sql",
    "ProductElements.sql", "OrderDetails.sql", "Reviews.sql", "CompanyOrders.sql",
    "Shipments.sql"
]

def automate_inserts():
    base_path = os.getcwd()

    with engine.connect() as connection:
        for file_name in sql_files:
            file_path = os.path.join(base_path, file_name)
            
            if not os.path.exists(file_path):
                continue

            table_name = file_name.replace(".sql", "")
            
            with open(file_path, 'r', encoding='utf-8') as f:
                sql_content = f.read()

                trans = connection.begin()
                try:
                    connection.execute(text(f"SET IDENTITY_INSERT {table_name} ON"))
                    connection.execute(text(sql_content))
                    connection.execute(text(f"SET IDENTITY_INSERT {table_name} OFF"))
                    trans.commit()
                    print(f"Imported: {table_name}")
                except Exception as e:
                    trans.rollback()
                    print(f"Error {file_name}: {str(e)}")

if __name__ == "__main__":
    automate_inserts()