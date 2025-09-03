// Supabase 초기 설정 파일
// 실제 사용 시 YOUR_SUPABASE_URL과 YOUR_SUPABASE_ANON_KEY를 본인의 값으로 교체하세요

// Supabase 클라이언트 설정
const SUPABASE_URL = 'https://nrblnfmknolgsqpcqite.supabase.co'; // 여기에 실제 Supabase URL 입력
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yYmxuZm1rbm9sZ3NxcGNxaXRlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4Nzg3NDEsImV4cCI6MjA3MjQ1NDc0MX0.8zy753R0nLtzr7a4UdpD1JjVUnNzikSfQTbO2sqnrUo'; // 여기에 실제 anon key 입력

// Supabase 클라이언트 초기화
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// 예약 데이터 삽입 함수
async function createReservation(reservationData) {
    try {
        const { data, error } = await supabaseClient
            .from('reservations')
            .insert([reservationData])
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약 생성 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약 목록 조회 함수
async function getReservations() {
    try {
        const { data, error } = await supabaseClient
            .from('reservations')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 특정 예약 조회 함수
async function getReservationById(id) {
    try {
        const { data, error } = await supabaseClient
            .from('reservations')
            .select('*')
            .eq('id', id)
            .single();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약 업데이트 함수
async function updateReservation(id, updates) {
    try {
        const { data, error } = await supabaseClient
            .from('reservations')
            .update(updates)
            .eq('id', id)
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약 업데이트 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약 삭제 함수
async function deleteReservation(id) {
    try {
        const { error } = await supabaseClient
            .from('reservations')
            .delete()
            .eq('id', id);

        if (error) {
            throw error;
        }

        return { success: true };
    } catch (error) {
        console.error('예약 삭제 오류:', error);
        return { success: false, error: error.message };
    }
}

// 날짜별 예약 조회 함수
async function getReservationsByDate(date) {
    try {
        const { data, error } = await supabaseClient
            .from('reservations')
            .select('*')
            .eq('reservation_date', date)
            .order('reservation_time', { ascending: true });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('날짜별 예약 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// ===============================
// 상품 관련 함수들 (Products)
// ===============================

// 상품 등록 함수
async function createProduct(productData) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .insert([productData])
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품 등록 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상품 목록 조회 함수
async function getProducts() {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 특정 상품 조회 함수
async function getProductById(id) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .select('*')
            .eq('id', id)
            .single();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상품번호로 상품 조회 함수 (중복 체크용)
async function getProductByCode(productCode) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .select('*')
            .eq('product_code', productCode)
            .maybeSingle();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품번호 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상품 업데이트 함수
async function updateProduct(id, updates) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .update(updates)
            .eq('id', id)
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품 업데이트 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상품 삭제 함수
async function deleteProduct(id) {
    try {
        const { error } = await supabaseClient
            .from('products')
            .delete()
            .eq('id', id);

        if (error) {
            throw error;
        }

        return { success: true };
    } catch (error) {
        console.error('상품 삭제 오류:', error);
        return { success: false, error: error.message };
    }
}

// 날짜별 상품 조회 함수
async function getProductsByDate(date) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .select('*')
            .eq('product_date', date)
            .order('start_time', { ascending: true });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('날짜별 상품 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 날짜별 예약 가능한 상품 조회 함수 (is_booked = false)
async function getAvailableProductsByDate(date) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .select('*')
            .eq('product_date', date)
            .eq('is_booked', false)
            .eq('status', 'active')
            .order('start_time', { ascending: true });

        if (error) {
            throw error;
        }

        console.log(`${date} 날짜의 예약 가능한 상품:`, data);
        return { success: true, data };
    } catch (error) {
        console.error('예약 가능 상품 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약 가능한 상품 개수 조회 함수
async function getAvailableProductsCountByDate(date) {
    try {
        const { count, error } = await supabaseClient
            .from('products')
            .select('*', { count: 'exact', head: true })
            .eq('product_date', date)
            .eq('is_booked', false)
            .eq('status', 'active');

        if (error) {
            throw error;
        }

        return { success: true, count };
    } catch (error) {
        console.error('예약 가능 상품 개수 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상품 예약 처리 함수 (is_booked를 true로 변경)
async function bookProduct(productId) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .update({ is_booked: true })
            .eq('id', productId)
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품 예약 처리 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상품 예약 취소 함수 (is_booked를 false로 변경)
async function cancelProductBooking(productId) {
    try {
        const { data, error } = await supabaseClient
            .from('products')
            .update({ is_booked: false })
            .eq('id', productId)
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상품 예약 취소 오류:', error);
        return { success: false, error: error.message };
    }
}

// ===============================
// 예약현황 관련 함수들 (Bookings)
// ===============================

// 모든 예약현황 조회 함수
async function getBookings() {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약현황 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 특정 예약현황 조회 함수
async function getBookingById(id) {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .select('*')
            .eq('id', id)
            .single();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약현황 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약현황 등록 함수
async function createBooking(bookingData) {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .insert([bookingData])
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약현황 등록 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약현황 업데이트 함수
async function updateBooking(id, updates) {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .update(updates)
            .eq('id', id)
            .select();

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('예약현황 업데이트 오류:', error);
        return { success: false, error: error.message };
    }
}

// 예약현황 삭제 함수
async function deleteBooking(id) {
    try {
        const { error } = await supabaseClient
            .from('bookings')
            .delete()
            .eq('id', id);

        if (error) {
            throw error;
        }

        return { success: true };
    } catch (error) {
        console.error('예약현황 삭제 오류:', error);
        return { success: false, error: error.message };
    }
}

// 상태별 예약현황 조회 함수
async function getBookingsByStatus(status) {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .select('*')
            .eq('status', status)
            .order('booking_date', { ascending: true });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('상태별 예약현황 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 날짜별 예약현황 조회 함수
async function getBookingsByDate(date) {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .select('*')
            .eq('booking_date', date)
            .order('booking_time', { ascending: true });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('날짜별 예약현황 조회 오류:', error);
        return { success: false, error: error.message };
    }
}

// 고객별 예약현황 조회 함수
async function getBookingsByCustomer(customerName) {
    try {
        const { data, error } = await supabaseClient
            .from('bookings')
            .select('*')
            .ilike('customer_name', `%${customerName}%`)
            .order('created_at', { ascending: false });

        if (error) {
            throw error;
        }

        return { success: true, data };
    } catch (error) {
        console.error('고객별 예약현황 조회 오류:', error);
        return { success: false, error: error.message };
    }
}