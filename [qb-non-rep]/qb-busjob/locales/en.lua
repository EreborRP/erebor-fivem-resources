local Translations = {
    error = {
        already_driving_bus = 'You are already driving a bus',
        not_in_bus = 'You are not in a bus',
        one_bus_active = 'You can only have one active bus at a time',
        drop_off_passengers = 'Drop off the passengers before you stop working',
        no_bus_job = 'You don\'t have bus job, please go to Town hall and pick it '
    },
    success = {
        success_payment = 'Person delivered you got $',
    },
    info = {
        bus = 'Standard Bus',
        goto_busstop = 'Go to the next bus stop',
        busstop_text = 'E - Open doors',
        bus_plate = 'BUS', -- Can be 3 or 4 characters long (uses random 4 digits)
        bus_depot = 'Bus Depot',
        bus_stop_work = 'E - Stop Working',
        bus_job_vehicles = 'E - Job Vehicles'
    },
    menu = {
        bus_header = '~ Bus Vehicles ~',
        bus_close = '⬅ Close Menu'
    }
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})