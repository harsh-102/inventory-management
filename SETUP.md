# Inventory Management System Setup Guide

Follow these steps to set up and run the Inventory Management System.

## Prerequisites

- Python 3.8 or higher
- MySQL Server 5.7 or higher
- pip (Python package manager)

## Step 1: Create and Configure the Database

1. Start MySQL server on your system
2. Log in to MySQL:
   ```bash
   mysql -u root -p
   ```
   Enter your MySQL root password when prompted.

3. Run the database setup script:
   ```bash
   mysql -u root -p < setup_database.sql
   ```
   This will create the necessary database, tables, triggers, procedures, and views.

4. Alternatively, you can copy and paste the contents of `setup_database.sql` into the MySQL console.

## Step 2: Configure the Application

1. Create a `.env` file in the project root directory with your MySQL credentials:
   ```
   DB_USER=root
   DB_PASSWORD=your_mysql_password
   DB_HOST=localhost
   DB_NAME=Inventory_Management
   ```

   Replace `your_mysql_password` with your actual MySQL password.

## Step 3: Set Up the Python Environment

1. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   ```

2. Activate the virtual environment:
   - On Windows:
     ```bash
     venv\Scripts\activate
     ```
   - On macOS/Linux:
     ```bash
     source venv/bin/activate
     ```

3. Install the required packages:
   ```bash
   pip install -r requirements.txt
   ```

## Step 4: Run the Application

1. Start the Flask server:
   ```bash
   python app.py
   ```

2. Open your web browser and navigate to:
   ```
   http://127.0.0.1:5000
   ```

## How the System Works

The Inventory Management System includes several automated features:

1. **Automatic Order Creation**: When a product's quantity falls below its minimum threshold, an order is automatically created for that product from its supplier.

2. **Automatic Shipment Creation**: When two or more orders are created on the same day, a shipment is automatically created to group those orders.

3. **Low Stock Monitoring**: Products with quantities below their minimum thresholds are displayed in the "Low Stock" section.

## Using the Application

1. **Add Suppliers**: First, add suppliers who provide your products.

2. **Add Products**: Add products with details including the supplier and minimum quantity thresholds.

3. **Update Product Quantities**: Update quantities as inventory changes. When a quantity falls below the minimum, an order is automatically created.

4. **Monitor Dashboard**: See key metrics including today's shipments and low stock products.

5. **View Orders and Shipments**: Orders and shipments are automatically created based on inventory changes and can be viewed in their respective sections.

## Sample Data (Optional)

To load sample data for testing, uncomment the sample data section in `setup_database.sql` and run it, or execute these SQL commands in the MySQL console.

## Troubleshooting

- **Database Connection Issues**: Verify your MySQL credentials in the `.env` file and ensure the MySQL server is running.

- **Import Errors**: Make sure all required packages are installed using `pip install -r requirements.txt`.

- **Trigger Issues**: If the triggers aren't working, check that your MySQL version supports triggers and that you have sufficient privileges.

- **Port Conflicts**: If port 5000 is already in use, modify `app.py` to use a different port. 