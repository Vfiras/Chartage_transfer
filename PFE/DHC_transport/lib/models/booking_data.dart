class BookingData {
  String pickup;
  String destination;
  String tripType;
  String departureDate;
  String departureTime;
  String returnDate;
  String returnTime;
  int passengers;
  int luggageCount;
  String promoCode;
  String serviceId;
  int? vehicleId;
  String vehicleClass;
  int seats;
  int luggage;
  double totalPrice;
  double subtotalPrice;
  double dynamicSurcharge;
  double discountAmount;
  String contactEmail;
  String contactPhone;

  BookingData({
    this.pickup = '',
    this.destination = '',
    this.tripType = 'one-way',
    this.departureDate = '',
    this.departureTime = '',
    this.returnDate = '',
    this.returnTime = '',
    this.passengers = 1,
    this.luggageCount = 1,
    this.promoCode = '',
    this.serviceId = '',
    this.vehicleId,
    this.vehicleClass = '',
    this.seats = 0,
    this.luggage = 0,
    this.totalPrice = 0,
    this.subtotalPrice = 0,
    this.dynamicSurcharge = 0,
    this.discountAmount = 0,
    this.contactEmail = '',
    this.contactPhone = '',
  });

  String get date => departureDate;
  set date(String value) => departureDate = value;

  String get time => departureTime;
  set time(String value) => departureTime = value;

  bool get isRoundTrip => tripType == 'round-trip';
}
