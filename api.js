
const express = require("express");
const bodyParser = require("body-parser");
const app = express();
app.use(bodyParser.json());

let keyStore = {}; // لتخزين المفاتيح حسب العنوان

app.post("/api/key_exchange", (req, res) => {
  const { address, public_key } = req.body;
  if (keyStore[address]) {
    // إذا كان هناك مفتاح مسجل بالفعل، يتم إرجاعه مع قيمة مفتاح مشترك (مثال توضيحي)
    res.json({
      their_public_key: keyStore[address],
      shared_secret: "", // يجب حساب المفتاح المشترك بطريقة آمنة على العميل
    });
  } else {
    // تسجيل المفتاح الجديد
    keyStore[address] = public_key;
    res.json({
      their_public_key: null,
      shared_secret: null,
    });
  }
});



app.listen(3000, () => console.log("Server running on port 3000"));