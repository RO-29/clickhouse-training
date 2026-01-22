// MongoDB Initialization Script for Migration Module
// Purpose: Create sample database with collections for Debezium CDC

db = db.getSiblingDB('source_db');

// Enable replica set for CDC (required for Debezium)
// Note: Single node replica set in Docker
rs.initiate({
    _id: 'rs0',
    members: [
        { _id: 0, host: 'mongodb:27017' }
    ]
});

// Create users collection
db.createCollection('users');
db.users.createIndex({ _id: 1 });
db.users.insertMany([
    {
        _id: ObjectId(),
        username: 'john_doe',
        email: 'john@example.com',
        status: 'active',
        created_at: new Date('2024-01-15'),
        updated_at: new Date('2024-01-15'),
        profile_data: { country: 'USA', city: 'New York' }
    },
    {
        _id: ObjectId(),
        username: 'jane_smith',
        email: 'jane@example.com',
        status: 'active',
        created_at: new Date('2024-01-16'),
        updated_at: new Date('2024-01-16'),
        profile_data: { country: 'UK', city: 'London' }
    },
    {
        _id: ObjectId(),
        username: 'bob_wilson',
        email: 'bob@example.com',
        status: 'inactive',
        created_at: new Date('2024-01-17'),
        updated_at: new Date('2024-01-17'),
        profile_data: { country: 'Canada', city: 'Toronto' }
    }
]);

// Create orders collection
db.createCollection('orders');
db.orders.createIndex({ user_id: 1 });
db.orders.createIndex({ created_at: 1 });
db.orders.insertMany([
    {
        _id: ObjectId(),
        user_id: 'user_001',
        order_number: 'ORD-2024-001',
        items: [
            { product_id: 'P001', name: 'Laptop', quantity: 1, price: 999.99 },
            { product_id: 'P002', name: 'Mouse', quantity: 2, price: 29.99 }
        ],
        total_amount: 1059.97,
        currency: 'USD',
        status: 'completed',
        created_at: new Date('2024-01-20'),
        updated_at: new Date('2024-01-20'),
        shipping_address: { street: '123 Main St', city: 'New York', zip: '10001' }
    },
    {
        _id: ObjectId(),
        user_id: 'user_002',
        order_number: 'ORD-2024-002',
        items: [
            { product_id: 'P003', name: 'Monitor', quantity: 1, price: 299.99 }
        ],
        total_amount: 299.99,
        currency: 'USD',
        status: 'pending',
        created_at: new Date('2024-01-21'),
        updated_at: new Date('2024-01-21'),
        shipping_address: { street: '456 Oak Ave', city: 'London', zip: 'SW1A' }
    },
    {
        _id: ObjectId(),
        user_id: 'user_001',
        order_number: 'ORD-2024-003',
        items: [
            { product_id: 'P004', name: 'Keyboard', quantity: 1, price: 79.99 }
        ],
        total_amount: 79.99,
        currency: 'USD',
        status: 'processing',
        created_at: new Date('2024-01-21'),
        updated_at: new Date('2024-01-21'),
        shipping_address: { street: '123 Main St', city: 'New York', zip: '10001' }
    }
]);

// Create products collection
db.createCollection('products');
db.products.createIndex({ _id: 1 });
db.products.createIndex({ category: 1 });
db.products.insertMany([
    {
        _id: ObjectId(),
        name: 'Laptop',
        category: 'Electronics',
        price: 999.99,
        description: 'High-performance laptop for professionals',
        stock_quantity: 50,
        created_at: new Date('2024-01-01'),
        updated_at: new Date('2024-01-01'),
        metadata: { brand: 'TechBrand', warranty_months: 24 }
    },
    {
        _id: ObjectId(),
        name: 'Mouse',
        category: 'Accessories',
        price: 29.99,
        description: 'Wireless mouse with ergonomic design',
        stock_quantity: 200,
        created_at: new Date('2024-01-01'),
        updated_at: new Date('2024-01-01'),
        metadata: { brand: 'Peripheral Co', warranty_months: 12 }
    },
    {
        _id: ObjectId(),
        name: 'Monitor',
        category: 'Electronics',
        price: 299.99,
        description: '27-inch 4K monitor',
        stock_quantity: 75,
        created_at: new Date('2024-01-01'),
        updated_at: new Date('2024-01-01'),
        metadata: { brand: 'DisplayCorp', warranty_months: 36 }
    },
    {
        _id: ObjectId(),
        name: 'Keyboard',
        category: 'Accessories',
        price: 79.99,
        description: 'Mechanical keyboard with RGB lighting',
        stock_quantity: 120,
        created_at: new Date('2024-01-01'),
        updated_at: new Date('2024-01-01'),
        metadata: { brand: 'KeyMaster', warranty_months: 12 }
    }
]);

// Create indexes for better performance
db.users.createIndex({ email: 1 }, { unique: true });
db.orders.createIndex({ order_number: 1 }, { unique: true });
db.products.createIndex({ name: 1 }, { unique: true });

// Verify collections were created
print('MongoDB initialization completed successfully');
print('Collections created:');
db.getCollectionNames().forEach(function(name) {
    print('  - ' + name + ' (' + db[name].countDocuments() + ' documents)');
});
