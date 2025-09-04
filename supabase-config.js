// Supabase 초기 설정 (env.js를 통해 주입)
// orig: 하드코딩된 URL/KEY가 있었으나 보안상 제거하고 외부 env로 이동

const SUPABASE_URL = (window.__ENV && window.__ENV.SUPABASE_URL) || "";
const SUPABASE_ANON_KEY = (window.__ENV && window.__ENV.SUPABASE_ANON_KEY) || "";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error("Supabase 환경변수가 설정되지 않았습니다. env.js를 생성하고 값을 채워주세요.");
}

// CDN으로 로드된 supabase 전역에서 createClient 추출
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ===============================
// Reservations (예약)
// ===============================

async function createReservation(reservationData) {
  try {
    const { data, error } = await supabaseClient.from('reservations').insert([reservationData]).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 생성 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getReservations() {
  try {
    const { data, error } = await supabaseClient
      .from('reservations')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getReservationById(id) {
  try {
    const { data, error } = await supabaseClient.from('reservations').select('*').eq('id', id).single();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 단건 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function updateReservation(id, updates) {
  try {
    const { data, error } = await supabaseClient.from('reservations').update(updates).eq('id', id).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 업데이트 오류:', error);
    return { success: false, error: error.message };
  }
}

async function deleteReservation(id) {
  try {
    const { error } = await supabaseClient.from('reservations').delete().eq('id', id);
    if (error) throw error;
    return { success: true };
  } catch (error) {
    console.error('예약 삭제 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getReservationsByDate(date) {
  try {
    const { data, error } = await supabaseClient
      .from('reservations')
      .select('*')
      .eq('reservation_date', date)
      .order('reservation_time', { ascending: true });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 날짜별 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// ===============================
// Products (상품)
// ===============================

async function createProduct(productData) {
  try {
    const { data, error } = await supabaseClient.from('products').insert([productData]).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('상품 등록 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getProducts() {
  try {
    const { data, error } = await supabaseClient.from('products').select('*').order('created_at', { ascending: false });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('상품 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getProductById(id) {
  try {
    const { data, error } = await supabaseClient.from('products').select('*').eq('id', id).single();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('상품 단건 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getProductByCode(productCode) {
  try {
    const { data, error } = await supabaseClient.from('products').select('*').eq('product_code', productCode).maybeSingle();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('상품 코드 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getAvailableProductsByDate(date) {
  try {
    const { data, error } = await supabaseClient
      .from('products')
      .select('*')
      .eq('product_date', date)
      .eq('is_booked', false)
      .eq('status', 'active')
      .order('start_time', { ascending: true });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약 가능 상품 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getAvailableProductsCountByDate(date) {
  try {
    const { count, error } = await supabaseClient
      .from('products')
      .select('*', { count: 'exact', head: true })
      .eq('product_date', date)
      .eq('is_booked', false)
      .eq('status', 'active');
    if (error) throw error;
    return { success: true, count };
  } catch (error) {
    console.error('예약 가능 상품 개수 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function bookProduct(productId) {
  try {
    const { data, error } = await supabaseClient.from('products').update({ is_booked: true }).eq('id', productId).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('상품 예약 처리 오류:', error);
    return { success: false, error: error.message };
  }
}

async function cancelProductBooking(productId) {
  try {
    const { data, error } = await supabaseClient.from('products').update({ is_booked: false }).eq('id', productId).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('상품 예약 취소 오류:', error);
    return { success: false, error: error.message };
  }
}

// ===============================
// Bookings (예약현황)
// ===============================

async function getBookings() {
  try {
    const { data, error } = await supabaseClient.from('bookings').select('*').order('created_at', { ascending: false });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getBookingById(id) {
  try {
    const { data, error } = await supabaseClient.from('bookings').select('*').eq('id', id).single();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 단건 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function createBooking(bookingData) {
  try {
    const { data, error } = await supabaseClient.from('bookings').insert([bookingData]).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 등록 오류:', error);
    return { success: false, error: error.message };
  }
}

async function updateBooking(id, updates) {
  try {
    const { data, error } = await supabaseClient.from('bookings').update(updates).eq('id', id).select();
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 업데이트 오류:', error);
    return { success: false, error: error.message };
  }
}

async function deleteBooking(id) {
  try {
    const { error } = await supabaseClient.from('bookings').delete().eq('id', id);
    if (error) throw error;
    return { success: true };
  } catch (error) {
    console.error('예약현황 삭제 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getBookingsByStatus(status) {
  try {
    const { data, error } = await supabaseClient
      .from('bookings')
      .select('*')
      .eq('status', status)
      .order('booking_date', { ascending: true });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 상태별 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getBookingsByDate(date) {
  try {
    const { data, error } = await supabaseClient
      .from('bookings')
      .select('*')
      .eq('booking_date', date)
      .order('booking_time', { ascending: true });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 날짜별 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

async function getBookingsByCustomer(customerName) {
  try {
    const { data, error } = await supabaseClient
      .from('bookings')
      .select('*')
      .ilike('customer_name', `%${customerName}%`)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return { success: true, data };
  } catch (error) {
    console.error('예약현황 고객명 조회 오류:', error);
    return { success: false, error: error.message };
  }
}

// 전역 노출 (브라우저 환경)
window.createReservation = createReservation;
window.getReservations = getReservations;
window.getReservationById = getReservationById;
window.updateReservation = updateReservation;
window.deleteReservation = deleteReservation;
window.getReservationsByDate = getReservationsByDate;

window.createProduct = createProduct;
window.getProducts = getProducts;
window.getProductById = getProductById;
window.getProductByCode = getProductByCode;
window.getAvailableProductsByDate = getAvailableProductsByDate;
window.getAvailableProductsCountByDate = getAvailableProductsCountByDate;
window.bookProduct = bookProduct;
window.cancelProductBooking = cancelProductBooking;

window.getBookings = getBookings;
window.getBookingById = getBookingById;
window.createBooking = createBooking;
window.updateBooking = updateBooking;
window.deleteBooking = deleteBooking;
window.getBookingsByStatus = getBookingsByStatus;
window.getBookingsByDate = getBookingsByDate;
window.getBookingsByCustomer = getBookingsByCustomer;

