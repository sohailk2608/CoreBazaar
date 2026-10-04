CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL UNIQUE,
    phone           TEXT UNIQUE,
    display_name    TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'closed')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_roles (
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK (role IN ('buyer', 'seller', 'admin')),
    PRIMARY KEY (user_id, role)
);

CREATE TABLE seller_profiles (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL UNIQUE REFERENCES users(id),
    business_name           TEXT NOT NULL,
    gstin                   TEXT,
    onboarding_status       TEXT NOT NULL DEFAULT 'pending'
                            CHECK (onboarding_status IN
                              ('pending', 'submitted', 'verified', 'rejected', 'suspended')),
    psp_seller_account_ref  TEXT UNIQUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE categories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id       UUID REFERENCES categories(id),
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    CHECK (parent_id IS NULL OR parent_id <> id)
);

CREATE TABLE category_closure (
    ancestor_id     UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    descendant_id   UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    depth           INTEGER NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX category_closure_descendant_idx
    ON category_closure (descendant_id, ancestor_id);

CREATE TABLE products (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id       UUID NOT NULL REFERENCES seller_profiles(id),
    category_id     UUID NOT NULL REFERENCES categories(id),
    sku             TEXT NOT NULL,
    title           TEXT NOT NULL,
    description     TEXT NOT NULL DEFAULT '',
    brand           TEXT,
    price_paise     BIGINT NOT NULL CHECK (price_paise >= 0),
    currency        CHAR(3) NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
    gst_rate_bps    INTEGER CHECK (gst_rate_bps BETWEEN 0 AND 10000),
    status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'active', 'out_of_stock', 'archived')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (seller_id, sku)
);

CREATE INDEX products_category_status_idx ON products (category_id, status);
CREATE INDEX products_seller_status_idx ON products (seller_id, status);

CREATE TABLE inventory (
    product_id      UUID PRIMARY KEY REFERENCES products(id),
    on_hand         INTEGER NOT NULL CHECK (on_hand >= 0),
    reserved        INTEGER NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (reserved <= on_hand)
);

CREATE TABLE orders (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id                UUID NOT NULL REFERENCES users(id),
    status                  TEXT NOT NULL DEFAULT 'pending_payment'
                            CHECK (status IN
                              ('pending_payment', 'paid', 'partially_fulfilled',
                               'fulfilled', 'cancelled', 'partially_refunded', 'refunded')),
    currency                CHAR(3) NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
    subtotal_paise          BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    tax_paise               BIGINT NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    shipping_paise          BIGINT NOT NULL DEFAULT 0 CHECK (shipping_paise >= 0),
    discount_paise          BIGINT NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
    total_paise             BIGINT NOT NULL CHECK (total_paise >= 0),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE seller_orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES orders(id),
    seller_id           UUID NOT NULL REFERENCES seller_profiles(id),
    status              TEXT NOT NULL DEFAULT 'awaiting_payment'
                        CHECK (status IN
                          ('awaiting_payment', 'paid', 'processing', 'shipped',
                           'delivered', 'cancelled', 'refunded')),
    subtotal_paise      BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    tax_paise           BIGINT NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    shipping_paise      BIGINT NOT NULL DEFAULT 0 CHECK (shipping_paise >= 0),
    UNIQUE (order_id, seller_id)
);

CREATE TABLE order_items (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_order_id         UUID NOT NULL REFERENCES seller_orders(id),
    product_id              UUID NOT NULL REFERENCES products(id),
    sku_snapshot            TEXT NOT NULL,
    title_snapshot          TEXT NOT NULL,
    quantity                INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_paise        BIGINT NOT NULL CHECK (unit_price_paise >= 0),
    tax_rate_bps_snapshot   INTEGER CHECK (tax_rate_bps_snapshot BETWEEN 0 AND 10000),
    tax_paise               BIGINT NOT NULL DEFAULT 0 CHECK (tax_paise >= 0)
);

CREATE TABLE payments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID NOT NULL REFERENCES orders(id),
    provider                TEXT NOT NULL,
    provider_order_ref      TEXT UNIQUE,
    provider_payment_ref    TEXT UNIQUE,
    method                  TEXT,
    status                  TEXT NOT NULL DEFAULT 'created'
                            CHECK (status IN
                              ('created', 'pending', 'authorized', 'succeeded',
                               'failed', 'partially_refunded', 'refunded')),
    amount_paise            BIGINT NOT NULL CHECK (amount_paise >= 0),
    currency                CHAR(3) NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
    idempotency_key         TEXT NOT NULL UNIQUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX payments_order_status_idx ON payments (order_id, status);

CREATE TABLE commission_splits (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id              UUID NOT NULL REFERENCES payments(id),
    seller_order_id         UUID NOT NULL UNIQUE REFERENCES seller_orders(id),
    gross_paise             BIGINT NOT NULL CHECK (gross_paise >= 0),
    commission_bps          INTEGER NOT NULL CHECK (commission_bps BETWEEN 0 AND 10000),
    platform_fee_paise      BIGINT NOT NULL CHECK (platform_fee_paise >= 0),
    seller_net_paise        BIGINT NOT NULL CHECK (seller_net_paise >= 0),
    psp_transfer_ref        TEXT UNIQUE,
    settlement_status       TEXT NOT NULL DEFAULT 'pending'
                            CHECK (settlement_status IN
                              ('pending', 'processing', 'settled', 'failed', 'reversed')),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (platform_fee_paise + seller_net_paise <= gross_paise)
);

CREATE TABLE payment_webhook_events (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider                TEXT NOT NULL,
    provider_event_id       TEXT NOT NULL,
    event_type              TEXT NOT NULL,
    received_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at            TIMESTAMPTZ,
    processing_status       TEXT NOT NULL DEFAULT 'received'
                            CHECK (processing_status IN ('received', 'processed', 'failed')),
    UNIQUE (provider, provider_event_id)
);

INSERT INTO categories (id, parent_id, name, slug, sort_order) VALUES
    ('10000000-0000-4000-8000-000000000001', NULL, 'Computer Parts', 'computer-parts', 1),
    ('10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
     'Storage', 'storage', 1),
    ('10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002',
     'NVMe SSDs', 'nvme-ssds', 1);

INSERT INTO category_closure (ancestor_id, descendant_id, depth) VALUES
    ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 0),
    ('10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 0),
    ('10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', 0),
    ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 1),
    ('10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000003', 1),
    ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 2);
