# Multi-User Inventory Management System

This is a web-based inventory management system that supports multiple users. Each user can manage their own suppliers, products, orders, and shipments.

## Features

- User registration and authentication
- Dashboard showing key metrics
- Supplier management
- Product inventory management
- Automatic order creation when products fall below minimum quantity
- Automatic shipment creation when multiple orders are placed on the same day
- Low stock alerts

## Setup Instructions

### Prerequisites

- Python 3.8+
- MySQL 8.0+
- pip (Python package manager)

### Installation

1. Clone the repository:
   ```
   git clone <repository-url>
   cd inventory-management
   ```

2. Create a virtual environment and activate it:
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install the required packages:
   ```
   pip install -r requirements.txt
   ```

4. Create a `.env` file in the project root and add your database credentials:
   ```
   DB_USER=your_mysql_username
   DB_PASSWORD=your_mysql_password
   DB_HOST=localhost
   DB_NAME=Inventory_Management
   SECRET_KEY=your_secret_key_for_sessions
   ```

5. Set up the database:
   - Create a MySQL database named `Inventory_Management`
   - Import the database schema:
     ```
     mysql -u your_username -p Inventory_Management < setup_database.sql
     ```

6. Start the application:
   ```
   python app.py
   ```

7. Open a web browser and navigate to:
   ```
   http://localhost:5000
   ```

8. Register a new account to start using the system

## Deployment Options

### Option 1: Deploy to PythonAnywhere

1. Sign up for a [PythonAnywhere](https://www.pythonanywhere.com/) account
2. Upload your code to PythonAnywhere
3. Create a MySQL database
4. Update your `.env` file with the PythonAnywhere database credentials
5. Set up a web app using Flask

### Option 2: Deploy to Heroku

1. Create a `Procfile` with the content:
   ```
   web: gunicorn app:app
   ```
2. Add `gunicorn` to your requirements.txt
3. Sign up for [Heroku](https://www.heroku.com/)
4. Create a Heroku app
5. Provision a MySQL add-on or use an external MySQL database
6. Set your environment variables in Heroku
7. Deploy your application:
   ```
   git push heroku main
   ```

## Default Admin Account

- Username: admin
- Password: admin123

## License

This project is licensed under the MIT License - see the LICENSE file for details. 