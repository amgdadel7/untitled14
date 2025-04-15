const express = require('express');
const mysql = require('mysql2/promise'); // تأكد من استخدام mysql2/promise
const crypto = require('crypto');
const EC = require('elliptic').ec;
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

// إعداد الاتصال بقاعدة البيانات
const pool = mysql.createPool({
  host: 'sql.freedb.tech',
  port: 3306,
  user: 'freedb_phone_info',
  password: 'GwUR7uUZ@p#P2?z',
  database: 'freedb_massege',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});
async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS device_info (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(255) UNIQUE NOT NULL,
        code VARCHAR(255) NOT NULL,
        phone_num VARCHAR(255) NOT NULL UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✅ جدول device_info جاهز');
  } catch (err) {
    console.error('❌ خطأ في إنشاء الجدول:', err);
    process.exit(1); // إنهاء التطبيق في حالة فشل إنشاء الجدول
  }
}

// نقطة تسجيل الجهاز
app.post('/api/device-info', async (req, res) => {
  const { uuid, code, phone_num } = req.body;
  await initializeDatabase();
  // استخدام Connection Pooling بشكل فعال
  const connection = await pool.getConnection();
  try {
    await connection.query('START TRANSACTION');
    const query = `
      INSERT INTO device_info (uuid, code, phone_num)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE
        code = VALUES(code),
        phone_num = VALUES(phone_num)
    `;
    await connection.query(query, [uuid, code, phone_num]);
    await connection.query('COMMIT');
    res.json({ success: true });
  } catch (err) {
    await connection.query('ROLLBACK');
    console.error('❌ خطأ في التسجيل:', err);
    res.status(500).json({ error: 'فشل في التسجيل' });
  } finally {
    connection.release();
  }
});
// إنشاء الجدول باستخدام async/await

app.post('/api/find-device', async (req, res) => {
  const { searchValue } = req.body;

  if (!searchValue) {
    return res.status(400).json({ error: 'يجب إرسال قيمة للبحث' });
  }

  try {
    // تعديل قيمة البحث بدون + أو بـ +

    const searchVariants = [
      searchValue,
      searchValue.startsWith('+') ? searchValue.substring(1) : `+${searchValue}`
    ];

    const query = `
      SELECT uuid
      FROM device_info
      WHERE phone_num = ? OR phone_num = ?
      LIMIT 1
    `;

    const [results] = await pool.query(query, searchVariants);

    if (results.length > 0) {
      return res.json({ uuid: results[0].uuid });
    } else {
      return res.status(404).json({ error: 'لا يوجد جهاز مطابق' });
    }
  } catch (err) {
    console.error('خطأ في البحث:', err);
    return res.status(500).json({ error: 'خطأ داخلي في الخادم' });
  }
});
// توليد المفاتيح باستخدام ECDH
const generateECDHKeys = () => {
  const ecdh = crypto.createECDH('secp256k1');
  ecdh.generateKeys();
  return {
    publicKey: ecdh.getPublicKey('hex'),
    privateKey: ecdh.getPrivateKey('hex')
  };
};

// نقطة تبادل المفاتيح المعدلة
app.post('/api/exchange-keys', async (req, res) => {
  const { senderUUID, receiverUUID, senderPublicKey, targetPhone } = req.body;

  try {
    // التحقق من وجود البيانات المطلوبة
    if (!senderUUID || !senderPublicKey || !targetPhone) {
      return res.status(400).json({ error: 'جميع الحقول مطلوبة' });
    }

    // التحقق من تنسيق المفتاح العام
    if (!senderPublicKey.startsWith('04') || senderPublicKey.length !== 130) {
      return res.status(400).json({ error: 'تنسيق المفتاح العام غير صالح' });
    }

    const ec = new EC('secp256k1');
    let publicKey;
    try {
      publicKey = ec.keyFromPublic(senderPublicKey, 'hex');
      if (!publicKey.validate()) {
        return res.status(400).json({ error: 'المفتاح العام غير صالح' });
      }
    } catch (e) {
      return res.status(400).json({ error: 'فشل في تحليل المفتاح العام' });
    }

    // البحث عن الجهاز المستقبل باستخدام query مباشرة من pool
    const [targetDevice] = await pool.query(
      'SELECT uuid, phone_num FROM device_info WHERE phone_num = ?',
      [targetPhone]
    );

    if (!targetDevice || targetDevice.length === 0) {
      return res.status(404).json({ error: 'الجهاز المستقبل غير مسجل' });
    }

    // توليد مفاتيح جديدة للجهاز المستقبل
    const ecdh = crypto.createECDH('secp256k1');
    ecdh.generateKeys();

    // إرجاع المفتاح العام غير المضغوط
    const targetPublicKey = ecdh.getPublicKey('hex', 'uncompressed');

    res.json({
      success: true,
      targetUUID: targetDevice[0].uuid,
      targetPublicKey: targetPublicKey,
      targetPhone: targetDevice[0].phone_num
    });

  } catch (e) {
    console.error('❌ خطأ في تبادل المفاتيح:', e);
    res.status(500).json({
      error: 'حدث خطأ في الخادم',
      details: e.message
    });
  }
});
async function createKeyInfoTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS key_info (
        id INT AUTO_INCREMENT PRIMARY KEY,
        senderUUID VARCHAR(255) NOT NULL,
        senderNUM VARCHAR(255),
        receiverUUID VARCHAR(255) NOT NULL,
        receiverNUM VARCHAR(255),
        sharedSecret TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_pair (senderUUID, receiverUUID)
      )
    `);
    console.log('✅ جدول key_info جاهز');
  } catch (err) {
    console.error('❌ خطأ في إنشاء جدول key_info:', err);
    throw err;
  }
}

// نقطة API لحفظ المفاتيح
app.post('/api/store-keys', async (req, res) => {
  const { senderUUID,senderNUM, receiverUUID,receiverNUM, sharedSecret } = req.body;

  try {
    // تأكد من وجود الجدول أولاً
    await createKeyInfoTable();

    const query = `
      INSERT INTO key_info (senderUUID,senderNUM, receiverUUID,receiverNUM, sharedSecret)
      VALUES (?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        sharedSecret = VALUES(sharedSecret),
        created_at = CURRENT_TIMESTAMP
    `;

    await pool.query(query, [senderUUID,senderNUM, receiverUUID,receiverNUM, sharedSecret]);
    res.json({ success: true });
  } catch (err) {
    console.error('❌ خطأ في حفظ المفاتيح:', err);
    res.status(500).json({
      error: 'فشل في حفظ المفاتيح',
      details: err.message
    });
  }
});
app.post('/api/get-keys', async (req, res) => {
  const { senderUUID, receiverUUID } = req.body;

  try {
    if (!senderUUID || !receiverUUID) {
      return res.status(400).json({
        error: 'يجب إرسال senderUUID و receiverUUID'
      });
    }

    const query = `
      SELECT
        senderUUID,
        senderNUM,
        receiverUUID,
        receiverNUM,
        sharedSecret,
        created_at
      FROM key_info
      WHERE senderUUID = ?
        AND receiverUUID = ?
    `;

    const [rows] = await pool.query(query, [senderUUID, receiverUUID]);

    if (rows.length === 0) {
      return res.status(404).json({
        message: 'لا توجد بيانات مطابقة'
      });
    }

    res.json({
      success: true,
      data: rows[0]
    });

  } catch (err) {
    console.error('❌ خطأ في استرجاع البيانات:', {
      error: err.message,
      query: err.sql,
      parameters: req.body
    });

    res.status(500).json({
      error: 'فشل في استرجاع البيانات',
      details: process.env.NODE_ENV === 'development'
        ? err.message
        : 'حدث خطأ غير متوقع'
    });
  }
});

app.listen(port, () => {
  console.log(`🚀 الخادم يعمل على المنفذ ${port}`);
});