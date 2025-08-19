-- BELLA'S BISTRO RESTAURANT DATABASE SCHEMA

-- Company Master Table
CREATE TABLE company (
    company_id INT PRIMARY KEY IDENTITY(1,1),
    company_name NVARCHAR(100) NOT NULL,
    headquarters_address NVARCHAR(500),
    founded_date DATE,
    business_type NVARCHAR(50) DEFAULT 'Restaurant Chain',
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- Franchise Owners
CREATE TABLE franchise_owners (
    franchise_owner_id INT PRIMARY KEY IDENTITY(1,1),
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    company_name NVARCHAR(100),
    email NVARCHAR(100) UNIQUE NOT NULL,
    phone NVARCHAR(20),
    contract_start_date DATE,
    franchise_fee DECIMAL(10,2),
    royalty_percentage DECIMAL(5,2),
    status NVARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Suspended')),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- Location Types: Restaurant, Food Truck, Ghost Kitchen
CREATE TABLE locations (
    location_id INT PRIMARY KEY IDENTITY(1,1),
    company_id INT NOT NULL,
    franchise_owner_id INT NULL, -- NULL for corporate-owned
    location_name NVARCHAR(100) NOT NULL,
    location_type NVARCHAR(20) NOT NULL CHECK (location_type IN ('Restaurant', 'Food Truck', 'Ghost Kitchen')),
    address NVARCHAR(500),
    city NVARCHAR(100),
    state NVARCHAR(50),
    zip_code NVARCHAR(10),
    phone NVARCHAR(20),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    opened_date DATE,
    status NVARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Closed', 'Under Construction')),
    monthly_rent DECIMAL(10,2),
    seating_capacity INT DEFAULT 0,
    drive_thru BOOLEAN DEFAULT 0,
    delivery_available BOOLEAN DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (company_id) REFERENCES company(company_id),
    FOREIGN KEY (franchise_owner_id) REFERENCES franchise_owners(franchise_owner_id)
);

-- Customer Database for Loyalty & Analytics
CREATE TABLE customers (
    customer_id INT PRIMARY KEY IDENTITY(1,1),
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100) UNIQUE,
    phone NVARCHAR(20),
    birth_date DATE,
    address NVARCHAR(500),
    city NVARCHAR(100),
    state NVARCHAR(50),
    zip_code NVARCHAR(10),
    registration_date DATE DEFAULT GETDATE(),
    loyalty_points INT DEFAULT 0,
    preferred_location_id INT,
    total_lifetime_value DECIMAL(10,2) DEFAULT 0,
    last_visit_date DATE,
    visit_frequency_days INT, -- Average days between visits
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (preferred_location_id) REFERENCES locations(location_id)
);

-- Employee Management
CREATE TABLE employees (
    employee_id INT PRIMARY KEY IDENTITY(1,1),
    location_id INT NOT NULL,
    employee_number NVARCHAR(20) UNIQUE,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    position NVARCHAR(50) NOT NULL,
    hourly_wage DECIMAL(8,2),
    hire_date DATE NOT NULL,
    status NVARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Terminated', 'On Leave')),
    phone NVARCHAR(20),
    emergency_contact NVARCHAR(100),
    emergency_phone NVARCHAR(20),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

-- Menu Categories
CREATE TABLE menu_categories (
    category_id INT PRIMARY KEY IDENTITY(1,1),
    category_name NVARCHAR(50) NOT NULL,
    description NVARCHAR(200),
    display_order INT DEFAULT 1,
    active BOOLEAN DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE()
);

-- Menu Items (Location-specific pricing)
CREATE TABLE menu_items (
    menu_item_id INT PRIMARY KEY IDENTITY(1,1),
    location_id INT NOT NULL,
    category_id INT NOT NULL,
    item_code NVARCHAR(20) UNIQUE, 
    item_name NVARCHAR(100) NOT NULL,
    description NVARCHAR(500),
    price DECIMAL(8,2) NOT NULL,
    cost_of_goods_sold DECIMAL(8,2), -- For profit margin analysis
    prep_time_minutes INT DEFAULT 10,
    calories INT,
    available BOOLEAN DEFAULT 1,
    dietary_flags NVARCHAR(100), 
    popularity_score INT DEFAULT 0, 
    profit_margin DECIMAL(5,2),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    FOREIGN KEY (category_id) REFERENCES menu_categories(category_id)
);

-- Promotions & Discounts
CREATE TABLE promotions (
    promotion_id INT PRIMARY KEY IDENTITY(1,1),
    promotion_code NVARCHAR(20) UNIQUE,
    promotion_name NVARCHAR(100) NOT NULL,
    description NVARCHAR(500),
    discount_amount DECIMAL(8,2),
    discount_percentage DECIMAL(5,2),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    applicable_items NVARCHAR(500), 
    usage_limit INT DEFAULT 999999,
    times_used INT DEFAULT 0,
    location_specific BOOLEAN DEFAULT 0,
    active BOOLEAN DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE()
);

-- Orders (Transactional Data)
CREATE TABLE orders (
    order_id INT PRIMARY KEY IDENTITY(1,1),
    order_number NVARCHAR(20) UNIQUE NOT NULL, 
    customer_id INT,
    location_id INT NOT NULL,
    employee_id INT,
    promotion_id INT,
    order_timestamp DATETIME2 DEFAULT GETDATE(),
    order_type NVARCHAR(20) NOT NULL CHECK (order_type IN ('Dine-In', 'Takeout', 'Delivery', 'Drive-Thru')),
    subtotal DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(8,2) DEFAULT 0,
    tip_amount DECIMAL(8,2) DEFAULT 0,
    discount_amount DECIMAL(8,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    payment_method NVARCHAR(20) CHECK (payment_method IN ('Cash', 'Credit Card', 'Debit Card', 'Mobile Payment', 'Gift Card')),
    status NVARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Preparing', 'Ready', 'Completed', 'Cancelled')),
    completed_timestamp DATETIME2,
    delivery_address NVARCHAR(500),
    special_requests NVARCHAR(500),
    
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    FOREIGN KEY (promotion_id) REFERENCES promotions(promotion_id)
);

-- Order Line Items
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY IDENTITY(1,1),
    order_id INT NOT NULL,
    menu_item_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(8,2) NOT NULL,
    special_instructions NVARCHAR(200),
    line_total DECIMAL(10,2) NOT NULL,
    
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(menu_item_id)
);

-- Ingredients Master
CREATE TABLE ingredients (
    ingredient_id INT PRIMARY KEY IDENTITY(1,1),
    ingredient_name NVARCHAR(100) NOT NULL,
    category NVARCHAR(50), 
    unit_of_measure NVARCHAR(20) NOT NULL, 
    standard_cost_per_unit DECIMAL(8,4),
    shelf_life_days INT,
    storage_requirements NVARCHAR(100), 
    allergen_info NVARCHAR(100),
    supplier_code NVARCHAR(50),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- Recipe Ingredients (Bill of Materials)
CREATE TABLE recipe_ingredients (
    recipe_id INT PRIMARY KEY IDENTITY(1,1),
    menu_item_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    quantity_needed DECIMAL(10,4) NOT NULL,
    preparation_notes NVARCHAR(200),
    
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(menu_item_id),
    FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id),
    UNIQUE(menu_item_id, ingredient_id)
);

-- Suppliers
CREATE TABLE suppliers (
    supplier_id INT PRIMARY KEY IDENTITY(1,1),
    supplier_name NVARCHAR(100) NOT NULL,
    contact_person NVARCHAR(100),
    phone NVARCHAR(20),
    email NVARCHAR(100),
    address NVARCHAR(500),
    city NVARCHAR(100),
    state NVARCHAR(50),
    zip_code NVARCHAR(10),
    specialty NVARCHAR(100),
    rating DECIMAL(3,2), 
    payment_terms NVARCHAR(50), 
    active BOOLEAN DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- Inventory Management (Location-specific)
CREATE TABLE inventory (
    inventory_id INT PRIMARY KEY IDENTITY(1,1),
    location_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    supplier_id INT,
    current_stock DECIMAL(10,4) NOT NULL DEFAULT 0,
    minimum_threshold DECIMAL(10,4) NOT NULL,
    maximum_capacity DECIMAL(10,4),
    cost_per_unit DECIMAL(8,4),
    last_updated DATETIME2 DEFAULT GETDATE(),
    expiration_date DATE,
    lot_number NVARCHAR(50),
    
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    UNIQUE(location_id, ingredient_id, lot_number)
);

-- Purchase Orders
CREATE TABLE purchase_orders (
    purchase_order_id INT PRIMARY KEY IDENTITY(1,1),
    po_number NVARCHAR(20) UNIQUE NOT NULL,
    location_id INT NOT NULL,
    supplier_id INT NOT NULL,
    order_date DATE NOT NULL DEFAULT GETDATE(),
    expected_delivery DATE,
    actual_delivery DATE,
    total_amount DECIMAL(10,2),
    status NVARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Ordered', 'Delivered', 'Cancelled')),
    notes NVARCHAR(500),
    created_by INT,
    
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    FOREIGN KEY (created_by) REFERENCES employees(employee_id)
);

-- Purchase Order Line Items
CREATE TABLE purchase_order_items (
    po_item_id INT PRIMARY KEY IDENTITY(1,1),
    purchase_order_id INT NOT NULL,
    ingredient_id INT NOT NULL,
    quantity_ordered DECIMAL(10,4) NOT NULL,
    unit_cost DECIMAL(8,4) NOT NULL,
    line_total DECIMAL(10,2) NOT NULL,
    quantity_received DECIMAL(10,4) DEFAULT 0,
    
    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(purchase_order_id) ON DELETE CASCADE,
    FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id)
);

-- Loyalty Points Transactions
CREATE TABLE loyalty_transactions (
    transaction_id INT PRIMARY KEY IDENTITY(1,1),
    customer_id INT NOT NULL,
    order_id INT,
    points_earned INT DEFAULT 0,
    points_redeemed INT DEFAULT 0,
    transaction_date DATETIME2 DEFAULT GETDATE(),
    transaction_type NVARCHAR(20) CHECK (transaction_type IN ('Earned', 'Redeemed', 'Expired', 'Adjustment')),
    description NVARCHAR(200),
    
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Daily Sales Summary (Analytical Table)
CREATE TABLE daily_sales_summary (
    sales_record_id INT PRIMARY KEY IDENTITY(1,1),
    location_id INT NOT NULL,
    business_date DATE NOT NULL,
    total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_orders INT NOT NULL DEFAULT 0,
    total_customers INT NOT NULL DEFAULT 0,
    average_order_value DECIMAL(8,2),
    food_cost_percentage DECIMAL(5,2),
    labor_cost_percentage DECIMAL(5,2),
    profit_margin DECIMAL(5,2),
    peak_hour_start TIME,
    peak_hour_end TIME,
    weather_condition NVARCHAR(50), 
    day_of_week NVARCHAR(10),
    created_at DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    UNIQUE(location_id, business_date)
);

