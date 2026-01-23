/**
 * Vanguard FYP - Cloud Functions for Push Notifications
 * 
 * 这个文件包含所有用于推送通知的 Cloud Functions
 * 使用 Firestore Triggers 监听数据变化并发送通知
 */

import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

// 初始化 Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * 辅助函数：获取用户的 FCM Tokens
 */
async function getUserFcmTokens(userId: string): Promise<string[]> {
  const accountDoc = await db.collection("accounts").doc(userId).get();
  const data = accountDoc.data();
  return data?.fcmTokens || [];
}

/**
 * 辅助函数：获取设施名称
 */
async function getFacilityName(facilityId: string): Promise<string> {
  const facilityDoc = await db.collection("facilities").doc(facilityId).get();
  return facilityDoc.data()?.name || "Facility";
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
