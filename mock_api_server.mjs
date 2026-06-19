import http from 'node:http';

const port = Number(process.env.PORT ?? 3000);

const orders = [
  {
    id: 'bk_1001',
    userId: 'user_001',
    userName: '李女士',
    salonName: 'Hot Pepper Beauty 银座店',
    staffName: 'Mika',
    serviceName: '日式层次剪发 + 护理',
    servicePrice: '¥8,800',
    serviceDuration: '90 分钟',
    startTime: '2026-06-15T16:30:00.000+08:00',
    status: 'pending',
    statusLabel: '待处理',
    userMessage: '希望刘海修短一点。',
    merchantMessage: '新预约申请，请确认该时段是否可接待。',
    rejectReason: null,
    createdAt: '2026-06-15T14:18:00.000+08:00',
    updatedAt: '2026-06-15T14:18:00.000+08:00',
  },
  {
    id: 'bk_1002',
    userId: 'user_002',
    userName: '陈先生',
    salonName: 'Hot Pepper Beauty 银座店',
    staffName: 'Ken',
    serviceName: '男士精剪',
    servicePrice: '¥5,500',
    serviceDuration: '60 分钟',
    startTime: '2026-06-16T11:00:00.000+08:00',
    status: 'accepted',
    statusLabel: '已接单',
    userMessage: '',
    merchantMessage: '预约已确认。',
    rejectReason: null,
    createdAt: '2026-06-15T10:05:00.000+08:00',
    updatedAt: '2026-06-15T10:30:00.000+08:00',
  },
];

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,PATCH,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json; charset=utf-8',
  });
  response.end(JSON.stringify(body));
}

function sendOptions(response) {
  response.writeHead(204, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,PATCH,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  response.end();
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.setEncoding('utf8');
    request.on('data', (chunk) => {
      body += chunk;
    });
    request.on('end', () => {
      if (!body) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(error);
      }
    });
    request.on('error', reject);
  });
}

function updateStatusLabel(order) {
  order.statusLabel = {
    accepted: '已接单',
    canceled: '已取消',
    completed: '已完成',
    pending: '待处理',
    rejected: '已拒单',
  }[order.status] ?? order.status;
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', `http://${request.headers.host}`);

  if (request.method === 'OPTIONS') {
    sendOptions(response);
    return;
  }

  if (request.method === 'GET' && url.pathname === '/api/merchant/bookings') {
    const status = url.searchParams.get('status');
    const filteredOrders = status
      ? orders.filter((order) => order.status === status)
      : orders;
    sendJson(response, 200, filteredOrders);
    return;
  }

  const bookingMatch = url.pathname.match(/^\/api\/merchant\/bookings\/([^/]+)$/);
  if (request.method === 'PATCH' && bookingMatch) {
    try {
      const bookingId = bookingMatch[1];
      const payload = await readJson(request);
      const order = orders.find((item) => item.id === bookingId);

      if (!order) {
        sendJson(response, 404, { message: 'Booking not found' });
        return;
      }

      const nextStatusByAction = {
        accept: 'accepted',
        cancel: 'canceled',
        complete: 'completed',
        reject: 'rejected',
      };
      const nextStatus = nextStatusByAction[payload.action];

      if (!nextStatus) {
        sendJson(response, 400, { message: 'Unsupported booking action' });
        return;
      }

      order.status = nextStatus;
      order.rejectReason =
        payload.action === 'reject' || payload.action === 'cancel'
          ? payload.reason ?? ''
          : null;
      order.merchantMessage =
        {
          accept: '商家已确认该预约。',
          cancel: '商家已取消该预约。',
          complete: '订单已完成。',
          reject: '商家已拒绝该预约。',
        }[payload.action] ?? order.merchantMessage;
      order.updatedAt = new Date().toISOString();
      updateStatusLabel(order);

      sendJson(response, 200, { booking: order });
    } catch (error) {
      sendJson(response, 400, { message: 'Invalid request body' });
    }
    return;
  }

  sendJson(response, 404, { message: 'Not found' });
});

server.listen(port, () => {
  console.log(`Mock merchant API running at http://localhost:${port}/api`);
});
