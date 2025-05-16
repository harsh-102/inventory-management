document.addEventListener('DOMContentLoaded', () => {
    // Get current user ID
    const userData = document.getElementById('user-data');
    const currentUserId = userData ? parseInt(userData.dataset.userId) : null;
    
    // Navigation
    const navButtons = document.querySelectorAll('.nav-btn');
    const sections = document.querySelectorAll('.section');

    navButtons.forEach(button => {
        button.addEventListener('click', () => {
            const targetSection = button.dataset.section;
            
            // Update active states
            navButtons.forEach(btn => btn.classList.remove('active'));
            sections.forEach(section => section.classList.remove('active'));
            
            button.classList.add('active');
            document.getElementById(targetSection).classList.add('active');
        });
    });

    // API Base URL
    const API_BASE = '/api';

    // Fetch and display data
    async function fetchData(endpoint) {
        try {
            const response = await fetch(`${API_BASE}/${endpoint}`);
            if (!response.ok) throw new Error('Network response was not ok');
            return await response.json();
        } catch (error) {
            console.error('Error fetching data:', error);
            return [];
        }
    }

    // Update dashboard
    async function updateDashboard() {
        const [products, orders, shipments, suppliers, lowStock, todayShipments] = await Promise.all([
            fetchData('products'),
            fetchData('orders'),
            fetchData('shipments'),
            fetchData('suppliers'),
            fetchData('low_stock'),
            fetchData('today_shipments')
        ]);

        document.getElementById('total-products').textContent = products.length;
        document.getElementById('active-orders').textContent = orders.length;
        document.getElementById('total-shipments').textContent = shipments.length;
        document.getElementById('total-suppliers').textContent = suppliers.length;

        // Display low stock products on dashboard
        const lowStockTable = document.querySelector('#low-stock-dashboard-table tbody');
        lowStockTable.innerHTML = lowStock.map(product => `
            <tr>
                <td>${product.product_id}</td>
                <td>${product.name}</td>
                <td>${product.quantity_available}</td>
                <td>${product.minimum_quantity}</td>
                <td>${product.supplier_id}</td>
            </tr>
        `).join('');

        // Display today's shipments on dashboard
        const todayShipmentsTable = document.querySelector('#today-shipments-table tbody');
        todayShipmentsTable.innerHTML = todayShipments.length > 0 ? 
            todayShipments.map(shipment => `
                <tr>
                    <td>${shipment.shipment_id}</td>
                    <td>${shipment.shipment_date}</td>
                    <td>${shipment.order_id}</td>
                    <td>${shipment.product_id}</td>
                    <td>${shipment.product_quantity}</td>
                </tr>
            `).join('') : 
            '<tr><td colspan="5" class="text-center">No shipments today</td></tr>';
    }

    // Form handlers
    function setupFormHandlers() {
        // Supplier form
        const supplierForm = document.getElementById('supplier-form-data');
        const addSupplierBtn = document.getElementById('add-supplier-btn');
        
        addSupplierBtn.addEventListener('click', () => {
            document.getElementById('supplier-form').style.display = 'block';
        });

        supplierForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(supplierForm);
            const data = Object.fromEntries(formData.entries());

            try {
                const response = await fetch(`${API_BASE}/suppliers`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    supplierForm.reset();
                    document.getElementById('supplier-form').style.display = 'none';
                    updateDashboard();
                    loadSuppliers();
                    alert('Supplier added successfully');
                }
            } catch (error) {
                console.error('Error adding supplier:', error);
                alert('Error adding supplier');
            }
        });

        // Product form
        const productForm = document.getElementById('product-form-data');
        const addProductBtn = document.getElementById('add-product-btn');
        
        addProductBtn.addEventListener('click', () => {
            document.getElementById('product-form').style.display = 'block';
            loadSuppliersForSelect();
        });

        productForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(productForm);
            const data = Object.fromEntries(formData.entries());
            data.unit_price = parseFloat(data.unit_price);
            data.quantity_available = parseInt(data.quantity_available);
            data.minimum_quantity = parseInt(data.minimum_quantity);
            data.supplier_id = parseInt(data.supplier_id);

            try {
                const response = await fetch(`${API_BASE}/products`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    productForm.reset();
                    document.getElementById('product-form').style.display = 'none';
                    updateDashboard();
                    loadProducts();
                    loadLowStock();
                    alert('Product added successfully');
                }
            } catch (error) {
                console.error('Error adding product:', error);
                alert('Error adding product');
            }
        });
        
        // Update quantity form
        const quantityForm = document.getElementById('quantity-form-data');
        
        quantityForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(quantityForm);
            const data = {
                product_id: parseInt(formData.get('product_id')),
                new_quantity: parseInt(formData.get('new_quantity'))
            };

            try {
                const response = await fetch(`${API_BASE}/products/update_quantity`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    quantityForm.reset();
                    document.getElementById('update-quantity-form').style.display = 'none';
                    
                    // Wait 1 second before refreshing to allow database triggers to complete
                    setTimeout(async () => {
                        await updateDashboard();
                        await loadProducts();
                        await loadLowStock();
                        await loadOrders(); // Added to refresh orders after quantity update
                        await loadShipments(); // Also refresh shipments
                        console.log("All data refreshed after quantity update");
                    }, 1000);
                    
                    alert('Product quantity updated successfully');
                }
            } catch (error) {
                console.error('Error updating quantity:', error);
                alert('Error updating quantity');
            }
        });
    }

    // Load data into tables
    async function loadSuppliers() {
        const suppliers = await fetchData('suppliers');
        const tbody = document.querySelector('#suppliers-table tbody');
        tbody.innerHTML = suppliers.length > 0 ? 
            suppliers.map(supplier => `
                <tr>
                    <td>${supplier.supplier_id}</td>
                    <td>${supplier.name}</td>
                    <td>${supplier.contact_person || '-'}</td>
                    <td>${supplier.phone_number || '-'}</td>
                    <td>${supplier.email || '-'}</td>
                    <td>
                        <button class="action-btn delete-btn" onclick="deleteSupplier(${supplier.supplier_id})">Delete</button>
                    </td>
                </tr>
            `).join('') : 
            '<tr><td colspan="6" class="text-center">No suppliers found</td></tr>';
    }

    async function loadProducts() {
        const products = await fetchData('products_with_suppliers');
        const tbody = document.querySelector('#products-table tbody');
        tbody.innerHTML = products.length > 0 ? 
            products.map(product => `
                <tr>
                    <td>${product.product_id}</td>
                    <td>${product.name}</td>
                    <td>${product.unit_price.toFixed(2)}</td>
                    <td>${product.quantity_available}</td>
                    <td>${product.minimum_quantity}</td>
                    <td>${product.supplier_name}</td>
                    <td>
                        <button class="action-btn update-btn" onclick="updateQuantity(${product.product_id})">Update Qty</button>
                        <button class="action-btn delete-btn" onclick="deleteProduct(${product.product_id})">Delete</button>
                    </td>
                </tr>
            `).join('') : 
            '<tr><td colspan="7" class="text-center">No products found</td></tr>';
    }

    async function loadOrders() {
        const orders = await fetchData('orders');
        const tbody = document.querySelector('#orders-table tbody');
        tbody.innerHTML = orders.length > 0 ? 
            orders.map(order => `
                <tr>
                    <td>${order.order_id}</td>
                    <td>${order.supplier_name}</td>
                    <td>${order.order_date}</td>
                    <td>${order.items.length} items</td>
                    <td>
                        <button class="action-btn view-btn" onclick="viewOrderDetails(${order.order_id}, '${order.supplier_name}', '${order.order_date}')">View Details</button>
                    </td>
                </tr>
            `).join('') : 
            '<tr><td colspan="5" class="text-center">No orders found</td></tr>';
    }

    async function loadShipments() {
        const shipments = await fetchData('shipments');
        const tbody = document.querySelector('#shipments-table tbody');
        tbody.innerHTML = shipments.length > 0 ? 
            shipments.map(shipment => `
                <tr>
                    <td>${shipment.shipment_id}</td>
                    <td>${shipment.shipment_date}</td>
                    <td>${shipment.estimated_arrival_date}</td>
                    <td>${shipment.orders.length} orders</td>
                    <td>
                        <button class="action-btn view-btn" onclick="viewShipmentDetails(${shipment.shipment_id}, '${shipment.shipment_date}')">View Details</button>
                    </td>
                </tr>
            `).join('') : 
            '<tr><td colspan="5" class="text-center">No shipments found</td></tr>';
    }
    
    async function loadLowStock() {
        const lowStock = await fetchData('low_stock');
        const tbody = document.querySelector('#low-stock-table tbody');
        tbody.innerHTML = lowStock.length > 0 ? 
            lowStock.map(product => `
                <tr>
                    <td>${product.product_id}</td>
                    <td>${product.name}</td>
                    <td>${product.quantity_available}</td>
                    <td>${product.minimum_quantity}</td>
                    <td>${product.supplier_id}</td>
                    <td>
                        <button class="action-btn update-btn" onclick="updateQuantity(${product.product_id})">Update Qty</button>
                    </td>
                </tr>
            `).join('') : 
            '<tr><td colspan="6" class="text-center">No low stock products found</td></tr>';
    }

    // Load data for select dropdowns
    async function loadSuppliersForSelect() {
        const suppliers = await fetchData('suppliers');
        const select = document.querySelector('select[name="supplier_id"]');
        select.innerHTML = '<option value="">Select Supplier</option>' +
            suppliers.map(supplier => `
                <option value="${supplier.supplier_id}">${supplier.name}</option>
            `).join('');
    }

    // Delete functions
    window.deleteSupplier = async (id) => {
        if (confirm('Are you sure you want to delete this supplier?')) {
            try {
                const response = await fetch(`${API_BASE}/suppliers/${id}`, {
                    method: 'DELETE'
                });
                if (response.ok) {
                    updateDashboard();
                    loadSuppliers();
                    alert('Supplier deleted successfully');
                }
            } catch (error) {
                console.error('Error deleting supplier:', error);
                alert('Error deleting supplier');
            }
        }
    };

    window.deleteProduct = async (id) => {
        if (confirm('Are you sure you want to delete this product?')) {
            try {
                const response = await fetch(`${API_BASE}/products/${id}`, {
                    method: 'DELETE'
                });
                if (response.ok) {
                    updateDashboard();
                    loadProducts();
                    loadLowStock();
                    alert('Product deleted successfully');
                } else {
                    const errorData = await response.json();
                    alert(errorData.error || 'Failed to delete product');
                }
            } catch (error) {
                console.error('Error deleting product:', error);
                alert('Error deleting product. Please try again later.');
            }
        }
    };
    
    window.updateQuantity = (productId) => {
        const form = document.getElementById('quantity-form-data');
        form.querySelector('input[name="product_id"]').value = productId;
        document.getElementById('update-quantity-form').style.display = 'block';
    };
    
    window.viewOrderDetails = async (orderId, supplierName, orderDate) => {
        try {
            const orders = await fetchData('orders');
            const order = orders.find(o => o.order_id === orderId);
            
            if (order) {
                const modal = document.getElementById('order-details-modal');
                const tbody = document.querySelector('#order-items-table tbody');
                
                tbody.innerHTML = order.items.map(item => `
                    <tr>
                        <td>${item.product_name}</td>
                        <td>${item.quantity}</td>
                    </tr>
                `).join('');
                
                modal.style.display = 'block';
                
                // Close modal logic
                modal.querySelector('.close').onclick = () => {
                    modal.style.display = 'none';
                };
                
                window.onclick = (event) => {
                    if (event.target === modal) {
                        modal.style.display = 'none';
                    }
                };
            }
        } catch (error) {
            console.error('Error loading order details:', error);
        }
    };
    
    window.viewShipmentDetails = async (shipmentId, shipmentDate) => {
        try {
            const shipments = await fetchData('shipments');
            const shipment = shipments.find(s => s.shipment_id === shipmentId);
            const orders = await fetchData('orders');
            
            if (shipment) {
                const modal = document.getElementById('shipment-details-modal');
                const tbody = document.querySelector('#shipment-orders-table tbody');
                
                const shipmentOrders = shipment.orders.map(so => {
                    const orderDetails = orders.find(o => o.order_id === so.order_id);
                    return orderDetails ? {
                        order_id: so.order_id,
                        supplier_name: orderDetails.supplier_name,
                        order_date: orderDetails.order_date
                    } : {
                        order_id: so.order_id,
                        supplier_name: 'Unknown',
                        order_date: 'Unknown'
                    };
                });
                
                tbody.innerHTML = shipmentOrders.map(order => `
                    <tr>
                        <td>${order.order_id}</td>
                        <td>${order.supplier_name}</td>
                        <td>${order.order_date}</td>
                    </tr>
                `).join('');
                
                modal.style.display = 'block';
                
                // Close modal logic
                modal.querySelector('.close').onclick = () => {
                    modal.style.display = 'none';
                };
                
                window.onclick = (event) => {
                    if (event.target === modal) {
                        modal.style.display = 'none';
                    }
                };
            }
        } catch (error) {
            console.error('Error loading shipment details:', error);
        }
    };

    // Initialize
    setupFormHandlers();
    updateDashboard();
    loadSuppliers();
    loadProducts();
    loadOrders();
    loadShipments();
    loadLowStock();
}); 