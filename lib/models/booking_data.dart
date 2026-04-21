class BookingData {
  String pickup;
  String destination;
  String tripType;
  String date;
  String time;
  int passengers;
  String serviceId;
  int? vehicleId;

  BookingData({
    this.pickup = '',
    this.destination = '',
    this.tripType = 'one-way',
    this.date = '',
    this.time = '',
    this.passengers = 1,
    this.serviceId = '',
    this.vehicleId,
  });
}