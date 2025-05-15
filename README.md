# Inventory Management System

A professional inventory management system built with Flask, MySQL, and modern frontend technologies.

## Features

- Dashboard with key metrics
- Supplier management
- Product management
- Order management
- Shipment tracking
- Modern, responsive UI
- Real-time data updates

## Prerequisites

- Python 3.8 or higher
- MySQL Server
- pip (Python package manager)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd inventory-management
```

2. Create and activate a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Set up the MySQL database:
```sql
CREATE DATABASE Inventory_Management;
```

5. Update the database configuration in `app.py` if needed:
```python
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql://username:password@localhost/Inventory_Management'
```

## Running the Application

1. Start the Flask server:
```bash
python app.py
```

2. Open your web browser and navigate to:
```
http://localhost:5000
```

## Project Structure

```
inventory-management/
├── app.py              # Flask application
├── requirements.txt    # Python dependencies
├── static/
│   ├── css/
│   │   └── style.css  # Stylesheet
│   └── js/
│       └── main.js    # Frontend JavaScript
├── templates/
│   └── index.html     # Main HTML template
└── README.md          # This file
```

## Usage

1. **Dashboard**
   - View key metrics and statistics
   - Quick overview of inventory status

2. **Suppliers**
   - Add new suppliers
   - View and manage supplier information
   - Delete suppliers

3. **Products**
   - Add new products
   - View and manage product details
   - Track product quantities
   - Delete products

4. **Orders**
   - Create new orders
   - Add multiple products to orders
   - View order history
   - Delete orders

5. **Shipments**
   - Track shipments
   - Update shipment status
   - View delivery estimates
   - Delete shipments

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 