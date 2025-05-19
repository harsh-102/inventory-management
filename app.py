from flask import Flask, render_template, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, date
import os
from dotenv import load_dotenv
from sqlalchemy import text

load_dotenv()

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+mysqlconnector://{os.getenv("DB_USER")}:{os.getenv("DB_PASSWORD")}@{os.getenv("DB_HOST")}:{os.getenv("DB_PORT")}/{os.getenv("DB_NAME")}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# Database Models
class Supplier(db.Model):
    __tablename__ = 'Supplier'
    supplier_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(255), nullable=False)
    address = db.Column(db.Text, nullable=False)
    contact_person = db.Column(db.String(255))
    phone_number = db.Column(db.String(20))
    email = db.Column(db.String(255))
    products = db.relationship('Product', backref='supplier', lazy=True)
    orders = db.relationship('Order', backref='supplier', lazy=True)

class Product(db.Model):
    __tablename__ = 'Product'
    product_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)
    unit_price = db.Column(db.Numeric(10,2), nullable=False)
    quantity_available = db.Column(db.Integer, nullable=False)
    minimum_quantity = db.Column(db.Integer, nullable=False)
    supplier_id = db.Column(db.Integer, db.ForeignKey('Supplier.supplier_id'), nullable=False)
    order_items = db.relationship('OrderItem', backref='product', lazy=True)

class Order(db.Model):
    __tablename__ = 'Order'
    order_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    supplier_id = db.Column(db.Integer, db.ForeignKey('Supplier.supplier_id'), nullable=False)
    order_date = db.Column(db.Date, nullable=False)
    order_items = db.relationship('OrderItem', backref='order', lazy=True)
    shipments = db.relationship('ShipmentOrder', backref='order', lazy=True)

class OrderItem(db.Model):
    __tablename__ = 'OrderItem'
    order_item_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    order_id = db.Column(db.Integer, db.ForeignKey('Order.order_id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('Product.product_id'), nullable=False)
    product_quantity = db.Column(db.Integer, nullable=False)

class Shipment(db.Model):
    __tablename__ = 'Shipment'
    shipment_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    shipment_date = db.Column(db.Date, nullable=False)
    estimated_arrival_date = db.Column(db.Date, nullable=False)
    orders = db.relationship('ShipmentOrder', backref='shipment', lazy=True)

class ShipmentOrder(db.Model):
    __tablename__ = 'ShipmentOrder'
    shipment_id = db.Column(db.Integer, db.ForeignKey('Shipment.shipment_id'), primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('Order.order_id'), primary_key=True)

# Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/suppliers', methods=['GET', 'POST'])
def handle_suppliers():
    if request.method == 'POST':
        data = request.json
        new_supplier = Supplier(
            name=data['name'],
            address=data['address'],
            contact_person=data.get('contact_person', ''),
            phone_number=data.get('phone_number', ''),
            email=data.get('email', '')
        )
        db.session.add(new_supplier)
        db.session.commit()
        return jsonify({"message": "Supplier added successfully"}), 201
    
    suppliers = Supplier.query.all()
    print(f"Fetching all suppliers. Found {len(suppliers)} suppliers.")
    for s in suppliers:
        print(f"  Supplier: {s.supplier_id} - {s.name}")
    
    return jsonify([{
        'supplier_id': s.supplier_id,
        'name': s.name,
        'address': s.address,
        'contact_person': s.contact_person,
        'phone_number': s.phone_number,
        'email': s.email
    } for s in suppliers])

@app.route('/api/suppliers/<int:supplier_id>', methods=['DELETE'])
def delete_supplier(supplier_id):
    supplier = Supplier.query.get_or_404(supplier_id)
    db.session.delete(supplier)
    db.session.commit()
    return jsonify({"message": "Supplier deleted successfully"}), 200

@app.route('/api/products', methods=['GET', 'POST'])
def handle_products():
    if request.method == 'POST':
        data = request.json
        # Use stored procedure to add product
        query = text("CALL AddProduct(:name, :description, :price, :qty, :min_qty, :supplier_id)")
        db.session.execute(query, {
            'name': data['name'],
            'description': data['description'],
            'price': data['unit_price'],
            'qty': data['quantity_available'],
            'min_qty': data['minimum_quantity'],
            'supplier_id': data['supplier_id']
        })
        db.session.commit()
        return jsonify({"message": "Product added successfully"}), 201
    
    products = Product.query.all()
    return jsonify([{
        'product_id': p.product_id,
        'name': p.name,
        'description': p.description,
        'unit_price': float(p.unit_price),
        'quantity_available': p.quantity_available,
        'minimum_quantity': p.minimum_quantity,
        'supplier_id': p.supplier_id
    } for p in products])

@app.route('/api/products/<int:product_id>', methods=['DELETE'])
def delete_product(product_id):
    try:
        # Use stored procedure to delete product
        query = text("CALL DeleteProduct(:pid)")
        db.session.execute(query, {'pid': product_id})
        db.session.commit()
        return jsonify({"message": "Product deleted successfully"}), 200
    except Exception as e:
        db.session.rollback()
        error_message = str(e)
        print(f"Error deleting product: {error_message}")
        return jsonify({"error": "Could not delete product. It may be referenced in orders or shipments."}), 400

@app.route('/api/products/update_quantity', methods=['POST'])
def update_product_quantity():
    data = request.json
    print(f"Updating product {data['product_id']} quantity to {data['new_quantity']}")
    
    try:
        product = Product.query.get_or_404(data['product_id'])
        old_quantity = product.quantity_available
        minimum_quantity = product.minimum_quantity
        
        print(f"Current quantity: {old_quantity}, Minimum quantity: {minimum_quantity}")
        
        # Update the product quantity
        product.quantity_available = data['new_quantity']
        db.session.commit()
        
        print(f"Quantity updated. Checking if {data['new_quantity']} < {minimum_quantity} to trigger order")
        
        # Check if this should have triggered an order
        if data['new_quantity'] < minimum_quantity:
            print("Quantity is below minimum, checking if order was created...")
            # Check if order was created
            today = date.today()
            new_order = Order.query.filter(
                Order.supplier_id == product.supplier_id,
                Order.order_date == today
            ).first()
            
            if new_order:
                print(f"Order created: Order ID {new_order.order_id}")
            else:
                print("No order was created!")
        
        return jsonify({"message": "Product quantity updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error updating quantity: {str(e)}")
        return jsonify({"error": str(e)}), 400

@app.route('/api/orders', methods=['GET'])
def get_orders():
    try:
        print("Fetching orders from database...")
        orders = Order.query.all()
        print(f"Found {len(orders)} orders")
        
        result = []
        for order in orders:
            print(f"Processing order {order.order_id} for supplier {order.supplier_id}")
            order_items = OrderItem.query.filter_by(order_id=order.order_id).all()
            print(f"  Order has {len(order_items)} items")
            
            order_data = {
                'order_id': order.order_id,
                'supplier_id': order.supplier_id,
                'supplier_name': order.supplier.name if order.supplier else 'Unknown',
                'order_date': order.order_date.strftime('%Y-%m-%d'),
                'items': [{
                    'product_id': item.product_id,
                    'product_name': item.product.name if item.product else f'Product {item.product_id}',
                    'quantity': item.product_quantity
                } for item in order_items]
            }
            result.append(order_data)
        
        print(f"Returning {len(result)} orders")
        return jsonify(result)
    except Exception as e:
        print(f"Error fetching orders: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/shipments', methods=['GET'])
def get_shipments():
    shipments = Shipment.query.all()
    result = []
    for shipment in shipments:
        shipment_orders = ShipmentOrder.query.filter_by(shipment_id=shipment.shipment_id).all()
        result.append({
            'shipment_id': shipment.shipment_id,
            'shipment_date': shipment.shipment_date.strftime('%Y-%m-%d'),
            'estimated_arrival_date': shipment.estimated_arrival_date.strftime('%Y-%m-%d'),
            'orders': [{
                'order_id': so.order_id
            } for so in shipment_orders]
        })
    return jsonify(result)

@app.route('/api/low_stock', methods=['GET'])
def get_low_stock():
    query = text("SELECT * FROM LowStockProducts")
    result = db.session.execute(query)
    low_stock = [{
        'product_id': row[0],
        'name': row[1],
        'quantity_available': row[2],
        'minimum_quantity': row[3],
        'supplier_id': row[4]
    } for row in result]
    return jsonify(low_stock)

@app.route('/api/today_shipments', methods=['GET'])
def get_today_shipments():
    query = text("SELECT * FROM TodayShipments")
    result = db.session.execute(query)
    shipments = [{
        'shipment_id': row[0],
        'shipment_date': row[1].strftime('%Y-%m-%d'),
        'order_id': row[2],
        'product_id': row[3],
        'product_quantity': row[4]
    } for row in result]
    return jsonify(shipments)

@app.route('/api/products_with_suppliers', methods=['GET'])
def get_products_with_suppliers():
    query = text("SELECT p.*, s.name AS supplier_name FROM Product p JOIN Supplier s ON p.supplier_id = s.supplier_id")
    result = db.session.execute(query)
    products = [{
        'product_id': row[0],
        'name': row[1],
        'description': row[2],
        'unit_price': float(row[3]),
        'quantity_available': row[4],
        'minimum_quantity': row[5],
        'supplier_id': row[6],
        'supplier_name': row[7]
    } for row in result]
    return jsonify(products)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)