/**
 * Vanguard FYP - Cloud Functions for Push Notifications
 * 
 * 这个文件包含所有用于推送通知的 Cloud Functions
 * 使用 Firestore Triggers 监听数据变化并发送通知
 */

import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { PAYPAL_CLIENT_ID as CONFIG_CLIENT_ID, PAYPAL_CLIENT_SECRET as CONFIG_CLIENT_SECRET } from "./paypalConfig";

// 初始化 Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const PAYPAL_SANDBOX_BASE = "https://api-m.sandbox.paypal.com";

function getPayPalCredentials(): { clientId: string; clientSecret: string } {
  const clientId = process.env.PAYPAL_CLIENT_ID || CONFIG_CLIENT_ID;
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET || CONFIG_CLIENT_SECRET;
  const invalid =
    !clientId ||
    !clientSecret ||
    clientId.includes("REPLACE_WITH") ||
    clientSecret.includes("REPLACE_WITH");
  if (invalid) {
    throw new HttpsError(
      "failed-precondition",
      "PayPal sandbox not configured. Edit functions/src/paypalConfig.ts and set PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET to your sandbox app credentials."
    );
  }
  return { clientId, clientSecret };
}

async function getPayPalAccessToken(): Promise<string> {
  const { clientId, clientSecret } = getPayPalCredentials();
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const res = await fetch(`${PAYPAL_SANDBOX_BASE}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": `Basic ${auth}`,
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) {
    const text = await res.text();
    throw new HttpsError("internal", `PayPal auth failed: ${text}`);
  }
  const data = (await res.json()) as { access_token: string };
  return data.access_token;
}

interface CreatePayPalOrderParams {
  amount: number;
  currency?: string;
  returnUrl: string;
  cancelUrl: string;
  userId: string;
  residentId: string;
  feeType: string;
  feeTypeKey: string;
  feeTypeName: string;
  description?: string;
}

/**
 * Create a PayPal Sandbox order. Returns orderId and approvalUrl for the client to redirect the user.
 * Saves pending order to Firestore for completion after user approves.
 */
export const createPayPalOrder = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }
    const uid = request.auth.uid;
    const data = request.data as CreatePayPalOrderParams;
    const { amount, returnUrl, cancelUrl, userId, residentId, feeType, feeTypeKey, feeTypeName, description } = data;
    if (typeof amount !== "number" || amount <= 0 || !returnUrl || !cancelUrl || !userId || !feeType || !feeTypeName) {
      throw new HttpsError("invalid-argument", "Missing or invalid: amount, returnUrl, cancelUrl, userId, feeType, feeTypeName.");
    }
    if (userId !== uid) {
      throw new HttpsError("permission-denied", "userId must match authenticated user.");
    }

    const token = await getPayPalAccessToken();
    const currency = data.currency || "MYR";
    const value = amount.toFixed(2);

    const createRes = await fetch(`${PAYPAL_SANDBOX_BASE}/v2/checkout/orders`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
      body: JSON.stringify({
        intent: "CAPTURE",
        purchase_units: [
          {
            amount: { currency_code: currency, value },
            description: description || feeTypeName,
          },
        ],
        application_context: {
          return_url: returnUrl,
          cancel_url: cancelUrl,
          brand_name: "Vanguard",
        },
      }),
    });

    if (!createRes.ok) {
      const errText = await createRes.text();
      throw new HttpsError("internal", `PayPal create order failed: ${errText}`);
    }

    const order = (await createRes.json()) as { id: string; links?: Array<{ rel: string; href: string }> };
    const orderId = order.id;
    const approveLink = order.links?.find((l) => l.rel === "approve");
    const approvalUrl = approveLink?.href;
    if (!approvalUrl) {
      throw new HttpsError("internal", "PayPal order missing approval link.");
    }

    await db.collection("pendingPayPalOrders").doc(orderId).set({
      userId,
      residentId,
      amount,
      feeType,
      feeTypeKey,
      feeTypeName,
      description: description || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { orderId, approvalUrl };
  }
);

/**
 * Capture a PayPal order after user approved. Call from app when user returns from PayPal.
 */
export const capturePayPalOrder = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }
    const uid = request.auth.uid;
    const { orderId } = request.data as { orderId?: string };
    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "orderId required.");
    }

    const pendingDoc = await db.collection("pendingPayPalOrders").doc(orderId).get();
    if (!pendingDoc.exists) {
      throw new HttpsError("not-found", "Pending order not found or already completed.");
    }
    const pending = pendingDoc.data()!;
    if (pending.userId !== uid) {
      throw new HttpsError("permission-denied", "Order does not belong to this user.");
    }

    const token = await getPayPalAccessToken();
    const captureRes = await fetch(`${PAYPAL_SANDBOX_BASE}/v2/checkout/orders/${orderId}/capture`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
    });

    if (!captureRes.ok) {
      const errText = await captureRes.text();
      throw new HttpsError("internal", `PayPal capture failed: ${errText}`);
    }

    const captureData = (await captureRes.json()) as { id: string; status: string };
    const captureId = captureData.id;
    const status = captureData.status;

    await db.collection("pendingPayPalOrders").doc(orderId).delete();

    return {
      success: status === "COMPLETED",
      orderId,
      captureId,
      status,
      pendingOrder: pending,
    };
  }
);

/**
 * 辅助函数：获取用户的 FCM Tokens（通过 account ID）
 */
async function getUserFcmTokens(userId: string): Promise<string[]> {
  const accountDoc = await db.collection("accounts").doc(userId).get();
  const data = accountDoc.data();
  return data?.fcmTokens || [];
}

/**
 * 辅助函数：通过 residentId 获取 FCM Tokens
 * （accounts 中可能存 residentId 或 doc id 与 residentId 相同）
 */
async function getFcmTokensByResidentId(residentId: string): Promise<string[]> {
  // 1. 先尝试直接用 residentId 作为 account doc id（owner 可能如此）
  const directDoc = await db.collection("accounts").doc(residentId).get();
  const directTokens = directDoc.data()?.fcmTokens || [];
  if (directTokens.length > 0) return directTokens;

  // 2. 查询 accounts 中 residentId 匹配的
  const accountsSnapshot = await db.collection("accounts")
    .where("residentId", "==", residentId)
    .get();

  const allTokens: string[] = [];
  accountsSnapshot.docs.forEach((doc) => {
    const tokens = doc.data().fcmTokens || [];
    allTokens.push(...tokens);
  });
  return allTokens;
}

/**
 * 辅助函数：获取设施名称
 */
async function getFacilityName(facilityId: string): Promise<string> {
  const facilityDoc = await db.collection("facilities").doc(facilityId).get();
  return facilityDoc.data()?.name || "Facility";
}

/**
 * 辅助函数：获取所有安保的 FCM Tokens
 */
async function getAllSecurityFcmTokens(): Promise<string[]> {
  const securitySnapshot = await db.collection("accounts")
    .where("role", "==", "security")
    .get();

  const allTokens: string[] = [];
  securitySnapshot.docs.forEach((doc) => {
    const tokens = doc.data().fcmTokens || [];
    allTokens.push(...tokens);
  });
  return allTokens;
}

/**
 * 辅助函数：获取住户信息
 */
async function getResidentInfo(residentId: string): Promise<{ name: string; unit: string }> {
  const residentDoc = await db.collection("residents").doc(residentId).get();
  const data = residentDoc.data();
  return {
    name: data?.fullName || "Unknown",
    unit: data?.unitNumber || "N/A",
  };
}

/**
 * 辅助函数：发送推送通知
 */
async function sendNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: { [key: string]: string }
): Promise<void> {
  if (tokens.length === 0) {
    console.log("No FCM tokens found, skipping notification");
    return;
  }

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title,
      body,
    },
    data: data || {},
    android: {
      notification: {
        channelId: "vanguard_high_importance",
        priority: "high",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    console.log(`Successfully sent ${response.successCount} notifications`);
    
    // 处理失败的 tokens（可能已过期）
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.log(`Failed to send to token ${tokens[idx]}: ${resp.error}`);
        }
      });
    }
  } catch (error) {
    console.error("Error sending notification:", error);
  }
}

// ============================================================
// 1. Facility Booking 通知
// ============================================================

/**
 * 预订创建时发送通知
 * 触发条件：bookings collection 新增文档
 */
export const onBookingCreated = onDocumentCreated(
  "bookings/{bookingId}",
  async (event) => {
    const booking = event.data?.data();
    if (!booking) return;

    const residentId = booking.residentId as string;
    const facilityId = booking.facilityId as string;
    const status = booking.status as string;

    // 只有 approved 状态才发送通知（自动审批）
    if (status !== "approved") return;

    const tokens = await getUserFcmTokens(residentId);
    const facilityName = await getFacilityName(facilityId);

    // 格式化预订时间
    const bookingDate = booking.bookingDate?.toDate();
    const timeStr = bookingDate 
      ? bookingDate.toLocaleString("en-MY", { 
          dateStyle: "medium", 
          timeStyle: "short" 
        })
      : "scheduled time";

    await sendNotification(
      tokens,
      "Booking Confirmed ✓",
      `Your ${facilityName} booking for ${timeStr} is confirmed.`,
      { route: "/user/bookFacility", type: "booking_confirmed" }
    );

    console.log(`Booking notification sent to resident ${residentId}`);
  }
);

/**
 * 预订状态更新时发送通知
 * 触发条件：bookings collection 文档更新
 */
export const onBookingUpdated = onDocumentUpdated(
  "bookings/{bookingId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const oldStatus = before.status as string;
    const newStatus = after.status as string;

    // 状态没变化，忽略
    if (oldStatus === newStatus) return;

    const residentId = after.residentId as string;
    const facilityId = after.facilityId as string;
    const tokens = await getUserFcmTokens(residentId);
    const facilityName = await getFacilityName(facilityId);

    let title = "";
    let body = "";

    if (newStatus === "cancelled") {
      title = "Booking Cancelled";
      body = `Your ${facilityName} booking has been cancelled.`;
    } else if (newStatus === "completed") {
      title = "Booking Completed";
      body = `Your ${facilityName} booking has been marked as completed.`;
    }

    if (title) {
      await sendNotification(
        tokens,
        title,
        body,
        { route: "/user/bookFacility", type: "booking_status_changed" }
      );
    }
  }
);

// ============================================================
// 2. Visitor 访客通知
// ============================================================

/**
 * 访客状态更新时通知住户
 * 触发条件：visitors collection 文档更新
 */
export const onVisitorStatusUpdated = onDocumentUpdated(
  "visitors/{visitorId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const oldStatus = before.status as string;
    const newStatus = after.status as string;

    // 状态没变化，忽略
    if (oldStatus === newStatus) return;

    const residentId = after.residentId as string;
    const visitorName = after.visitorName as string || "Visitor";
    const tokens = await getUserFcmTokens(residentId);

    let title = "";
    let body = "";

    switch (newStatus) {
      case "approved":
        title = "Visitor Approved ✓";
        body = `${visitorName} has been approved for entry.`;
        break;
      case "denied":
        title = "Visitor Denied";
        body = `${visitorName}'s entry request was denied.`;
        break;
      case "checked-in":
        title = "Visitor Arrived 🚶";
        body = `${visitorName} has checked in at the gate.`;
        break;
      case "checked-out":
        title = "Visitor Left";
        body = `${visitorName} has checked out.`;
        break;
    }

    if (title) {
      await sendNotification(
        tokens,
        title,
        body,
        { route: "/user/registerVisitor", type: "visitor_status_changed" }
      );
    }
  }
);

// ============================================================
// 3. Maintenance 维修通知
// ============================================================

/**
 * 维修请求状态更新时通知住户
 * 触发条件：maintenanceRequests collection 文档更新
 */
export const onMaintenanceStatusUpdated = onDocumentUpdated(
  "maintenanceRequests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const oldStatus = before.status as string;
    const newStatus = after.status as string;

    // 状态没变化，忽略
    if (oldStatus === newStatus) return;

    const residentId = after.residentId as string;
    const category = after.category as string || "Maintenance";
    const tokens = await getUserFcmTokens(residentId);

    let title = "";
    let body = "";

    switch (newStatus) {
      case "in_progress":
        title = "Maintenance In Progress 🔧";
        body = `Your ${category} request is now being handled.`;
        break;
      case "resolved":
        title = "Maintenance Resolved ✓";
        body = `Your ${category} request has been resolved.`;
        break;
      case "rejected":
        title = "Maintenance Rejected";
        body = `Your ${category} request was rejected.`;
        break;
    }

    if (title) {
      await sendNotification(
        tokens,
        title,
        body,
        { route: "/user/maintenanceRequest", type: "maintenance_status_changed" }
      );
    }
  }
);

// ============================================================
// 4. Admin 通知（新业主注册）
// ============================================================

/**
 * 新业主注册时通知所有 Admin
 * 触发条件：accounts collection 新增 owner 文档
 */
export const onNewOwnerRegistration = onDocumentCreated(
  "accounts/{accountId}",
  async (event) => {
    const account = event.data?.data();
    if (!account) return;

    const role = account.role as string;
    const status = account.status as string;

    // 只处理新的 pending owner
    if (role !== "owner" || status !== "pending") return;

    // 获取所有 admin 的 FCM tokens
    const adminsSnapshot = await db.collection("accounts")
      .where("role", "==", "admin")
      .get();

    const allTokens: string[] = [];
    adminsSnapshot.docs.forEach((doc) => {
      const tokens = doc.data().fcmTokens || [];
      allTokens.push(...tokens);
    });

    if (allTokens.length === 0) return;

    await sendNotification(
      allTokens,
      "New Owner Registration 📝",
      "A new owner registration is pending approval.",
      { route: "/admin/ownerApprovals", type: "new_owner_pending" }
    );

    console.log(`Admin notification sent for new owner registration`);
  }
);

// ============================================================
// 5. 支付通知 (Payment Notifications)
// ============================================================

/**
 * 获取费用类型显示名称
 */
function getFeeTypeDisplayName(feeTypeKey: string): string {
  const names: Record<string, string> = {
    maintenance: "Maintenance",
    managementFee: "Management Fee",
    insurance: "Insurance",
    sinking: "Sinking Fund",
    waterBill: "Water Bill",
    electricBill: "Electric Bill",
    lateFee: "Late Fee",
  };
  return names[feeTypeKey] || feeTypeKey;
}

/**
 * 新费用推送时通知住户
 * 触发条件：pendingFees collection 新增文档
 */
export const onPendingFeeCreated = onDocumentCreated(
  "pendingFees/{feeId}",
  async (event) => {
    const fee = event.data?.data();
    if (!fee) return;

    const residentId = fee.residentId as string;
    const amount = fee.amount as number;
    const feeTypeKey = (fee.feeType as string) || "other";
    const dueDate = fee.dueDate?.toDate();
    const description = (fee.description as string) || "";

    const tokens = await getFcmTokensByResidentId(residentId);
    if (tokens.length === 0) {
      console.log(`No FCM tokens for resident ${residentId}, skipping payment notification`);
      return;
    }

    const feeTypeName = getFeeTypeDisplayName(feeTypeKey);
    const dueStr = dueDate
      ? dueDate.toLocaleDateString("en-MY", { dateStyle: "medium" })
      : "see details";

    await sendNotification(
      tokens,
      "New Payment Due 📋",
      `${feeTypeName}: RM ${amount.toFixed(2)} due by ${dueStr}. ${description ? description.substring(0, 50) + (description.length > 50 ? "..." : "") : ""}`,
      { route: "/user/payment", type: "payment_due" }
    );

    console.log(`Payment notification sent to resident ${residentId} for ${feeTypeName}`);
  }
);

/**
 * 逾期费用检查 - 每天 9:00 运行
 * 对已逾期的未缴纳费用发送逾期提醒
 */
export const checkLatePayments = onSchedule(
  {
    schedule: "0 9 * * *",  // 每天上午 9:00 (Asia/Kuala_Lumpur)
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // 查询 status=pending 且 dueDate < now 且未发过逾期提醒
    const lateFeesSnapshot = await db.collection("pendingFees")
      .where("status", "==", "pending")
      .where("dueDate", "<", now)
      .get();

    // 按 residentId 分组
    const feesByResident = new Map<string, Array<{ doc: admin.firestore.DocumentSnapshot; data: Record<string, unknown> }>>();
    for (const doc of lateFeesSnapshot.docs) {
      const data = doc.data();
      if (data.latePaymentNotified) continue;
      const residentId = data.residentId as string;
      if (!feesByResident.has(residentId)) {
        feesByResident.set(residentId, []);
      }
      feesByResident.get(residentId)!.push({ doc, data });
    }

    let alertCount = 0;
    for (const [residentId, fees] of feesByResident) {
      const tokens = await getFcmTokensByResidentId(residentId);
      if (tokens.length === 0) continue;

      // 汇总所有逾期费用
      const feeItems = fees.map(({ data }) => {
        const feeTypeName = getFeeTypeDisplayName((data.feeType as string) || "other");
        const amount = data.amount as number;
        const dueDate = (data.dueDate as admin.firestore.Timestamp | undefined)?.toDate?.();
        const dueStr = dueDate ? dueDate.toLocaleDateString("en-MY", { dateStyle: "medium" }) : "past due";
        return `${feeTypeName} RM ${amount.toFixed(2)} (due ${dueStr})`;
      });
      const totalAmount = fees.reduce((sum, { data }) => sum + (data.amount as number), 0);
      const body = fees.length === 1
        ? `Your payment is overdue! ${feeItems[0]}. Please pay as soon as possible.`
        : `You have ${fees.length} overdue payments (RM ${totalAmount.toFixed(2)} total): ${feeItems.join("; ")}. Please pay as soon as possible.`;

      await sendNotification(
        tokens,
        "⚠️ Late Payment Alert",
        body,
        { route: "/user/payment", type: "late_payment" }
      );

      // 标记所有该住户的逾期费用为已通知
      for (const { doc } of fees) {
        await doc.ref.update({ latePaymentNotified: true });
      }
      alertCount++;
    }

    console.log(`Late payment check: ${lateFeesSnapshot.size} overdue fees, ${alertCount} residents notified`);
  }
);

// ============================================================
// 6. 访客停车超时检查（定时任务）
// ============================================================

/**
 * 每 15 分钟检查停车超时
 * 1. 检查已入场超过 4 小时的 car 访客
 * 2. 检查凌晨 2 点后还在的 car 访客
 * 3. 检查过期的 QR 码
 */
export const checkVisitorOvertime = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const securityTokens = await getAllSecurityFcmTokens();
    
    if (securityTokens.length === 0) {
      console.log("No security tokens found, skipping notifications");
      return;
    }

    // 1. 检查停车超时（parkingDeadline 已过）
    const overtimeSnapshot = await db.collection("visitors")
      .where("status", "==", "checked-in")
      .where("entryType", "==", "car")
      .where("parkingDeadline", "<", now)
      .get();

    for (const doc of overtimeSnapshot.docs) {
      const data = doc.data();
      const visitorName = data.visitorName || "Visitor";
      const vehiclePlate = data.vehiclePlate || "N/A";
      const residentId = data.residentId || "";
      
      // 检查是否已经通知过（避免重复通知）
      if (data.overtimeNotified) continue;
      
      const residentInfo = await getResidentInfo(residentId);
      
      await sendNotification(
        securityTokens,
        "Parking Overtime ⏰",
        `${visitorName} (${vehiclePlate}) has exceeded parking time. Resident: ${residentInfo.name}, Unit ${residentInfo.unit}`,
        { route: "/security/visitorTracking", type: "parking_overtime" }
      );
      
      // 标记已通知
      await doc.ref.update({ overtimeNotified: true });
      
      console.log(`Overtime notification sent for visitor ${doc.id}`);
    }

    // 2. 检查过期的 QR 码（approved 状态但 qrExpiresAt 已过）
    const expiredQrSnapshot = await db.collection("visitors")
      .where("status", "==", "approved")
      .where("qrExpiresAt", "<", now)
      .get();

    for (const doc of expiredQrSnapshot.docs) {
      await doc.ref.update({ status: "expired" });
      console.log(`Visitor ${doc.id} QR code expired`);
    }

    console.log(`Overtime check completed. Overtime: ${overtimeSnapshot.size}, Expired QR: ${expiredQrSnapshot.size}`);
  }
);

/**
 * 凌晨 2 点警告 - 检查所有还在场内的 car 访客
 * 每天凌晨 2:00 运行
 */
export const midnightParkingAlert = onSchedule(
  {
    schedule: "0 2 * * *",  // 每天凌晨 2:00
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const securityTokens = await getAllSecurityFcmTokens();
    
    if (securityTokens.length === 0) {
      console.log("No security tokens found, skipping midnight alert");
      return;
    }

    // 获取所有还在场内的 car 访客
    const checkedInCarsSnapshot = await db.collection("visitors")
      .where("status", "==", "checked-in")
      .where("entryType", "==", "car")
      .get();

    if (checkedInCarsSnapshot.empty) {
      console.log("No car visitors still checked in at 2 AM");
      return;
    }

    // 收集所有超时访客信息
    const visitorInfos: string[] = [];
    
    for (const doc of checkedInCarsSnapshot.docs) {
      const data = doc.data();
      const visitorName = data.visitorName || "Unknown";
      const vehiclePlate = data.vehiclePlate || "N/A";
      const residentId = data.residentId || "";
      
      const residentInfo = await getResidentInfo(residentId);
      visitorInfos.push(`${visitorName} (${vehiclePlate}) - Unit ${residentInfo.unit}`);
      
      // 标记为过期
      await doc.ref.update({ 
        status: "expired",
        expiredReason: "2AM_deadline",
      });
    }

    // 发送汇总通知
    await sendNotification(
      securityTokens,
      "🚨 2 AM Parking Alert",
      `${visitorInfos.length} car visitor(s) still on premises: ${visitorInfos.slice(0, 3).join(", ")}${visitorInfos.length > 3 ? "..." : ""}`,
      { route: "/security/visitorTracking", type: "midnight_alert" }
    );

    console.log(`2 AM alert sent for ${visitorInfos.length} visitors`);
  }
);

/**
 * 每小时检查 walk-in 访客是否超过 24 小时
 */
export const checkWalkInOvertime = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 24 * 60 * 60 * 1000
    );
    
    const securityTokens = await getAllSecurityFcmTokens();

    // 获取超过 24 小时还在的 walk-in 访客
    const overtimeWalkInSnapshot = await db.collection("visitors")
      .where("status", "==", "checked-in")
      .where("entryType", "==", "walk-in")
      .where("checkedInAt", "<", twentyFourHoursAgo)
      .get();

    for (const doc of overtimeWalkInSnapshot.docs) {
      const data = doc.data();
      
      // 检查是否已通知过
      if (data.overtimeNotified) continue;
      
      const visitorName = data.visitorName || "Visitor";
      const residentId = data.residentId || "";
      const residentInfo = await getResidentInfo(residentId);
      
      if (securityTokens.length > 0) {
        await sendNotification(
          securityTokens,
          "Visitor Overstay ⚠️",
          `${visitorName} (walk-in) has been on premises for over 24 hours. Resident: ${residentInfo.name}, Unit ${residentInfo.unit}`,
          { route: "/security/visitorTracking", type: "walkin_overtime" }
        );
      }
      
      // 标记已通知并过期
      await doc.ref.update({ 
        overtimeNotified: true,
        status: "expired",
        expiredReason: "24h_overtime",
      });
      
      console.log(`Walk-in overtime notification sent for visitor ${doc.id}`);
    }

    console.log(`Walk-in overtime check completed. Found: ${overtimeWalkInSnapshot.size}`);
  }
);
