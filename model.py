import itertools
import pandas as pd
import pynetlogo

# Path to your NetLogo model
netlogo_model_path = 'Traffic Intersection_dev.nlogo'

# Initialize NetLogo link
netlogo = pynetlogo.NetLogoLink(gui=False, netlogo_home='C:/Program Files/NetLogo 6.4.0')
netlogo.load_model(netlogo_model_path)

# ask for grid size
grid_size_x = int(input("Enter the grid size for x: "))
grid_size_y = int(input("Enter the grid size for y: "))

freq_west = int(input("Enter the frequency of vehicles for west: "))
freq_north = int(input("Enter the frequency of vehicles for north: "))

netlogo.command(f"set grid-size-x {grid_size_x}")
netlogo.command(f"set grid-size-y {grid_size_y}")
netlogo.command(f"set freq-north {freq_north}")
netlogo.command(f"set freq-west {freq_west}")

default_states = [
    "set auto? False",
    "set allow-priority? False",
    "set adaptive-density? False",
    "set adaptive-waiting-time? False",
    "set priority-score? False",
    "set multi-agent? False"
]

# Additional Parameters
green_lengths = range(1, 21) 
yellow_lengths = range(1, 6)
neighbors_asked = range(1, max(grid_size_x, grid_size_y))

# Priority Score Weights
#density_weights = range(0, 101)
density_weights =  [0, 10, 20,25, 30,33, 34, 40 ,50, 60, 80, 100]
#waiting_time_weights = range(0, 101)
waiting_time_weights = [0, 10, 20,25, 30,33, 34, 40 ,50, 60, 80, 100]
#priority_vehicle_weights = range(0, 101)
priority_vehicle_weights =  [0, 10, 20,25, 30,33, 34, 40 ,50, 60, 80, 100]
# Constraint: Sum of weights <= 100
valid_weight_combinations = [
    (d, w, p)
    for d, w, p in itertools.product(density_weights, waiting_time_weights, priority_vehicle_weights)
    if d + w + p == 100
]

def default_state():
    for state in default_states:
        netlogo.command(state)
    
def set_strategy(strategy):
    for strat in default_states:
        if strategy in strat:
            if(strategy == "allow-priority?"):
                netlogo.command("set auto? True")
            netlogo.command(f"set {strategy} True")

def run_model(strategy, yellow_length ,green_length=None, neighbors=None, weights=None):
    # Set parameters in NetLogo
    default_state()
    set_strategy(strategy)
    if(green_length != None):
        netlogo.command(f"set green-length {green_length}")
        
    netlogo.command(f"set yellow-length {yellow_length}")
    if neighbors:
        netlogo.command(f"set neighbors-asked {neighbors}")
    
    # Set priority weights (only if priority-score? is True or multi-agent? is True)
    if strategy in ["priority-score?", "multi-agent?"]:
        netlogo.command(f"set density-weight {weights[0]}")
        netlogo.command(f"set waiting-time-weight {weights[1]}")
        netlogo.command(f"set priority-vehicle-weight {weights[2]}")

    # Run the model
    netlogo.command("setup")
    netlogo.repeat_command("go", 10000)  # Simulate 100 ticks

    # Collect performance metrics
    total_traffic_input = netlogo.report("total-traffic-input")
    total_traffic_output = netlogo.report("total-traffic-output")
    total_waiting_time = netlogo.report("report-total-waiting-time")
    avg_total_waiting_time = netlogo.report(" average-total-waiting-time")
    total_accidents = netlogo.report("report-total-accidents")
    priority_avg_waiting_time = netlogo.report("report-average-priority-vehicles")
    priority_vehicles_count=netlogo.report("total-priority-vehicles")
    results = []
    # Store results
    results.append({
        "Strategy": strategy,
        "Green Length": green_length,
        "Yellow Length": yellow_length,
        "Neighbors Asked": neighbors,
        "Weights": weights if strategy in ["priority-score?", "multi-agent?"] else None,
        "Total Traffic Input": total_traffic_input,
        "Total Traffic Output": total_traffic_output,
        "Total Waiting Time": total_waiting_time,
        "Average Total Waiting Time": avg_total_waiting_time,
        "Total Accidents": total_accidents,
        "Priority Vehicles Count": priority_vehicles_count,
        "Priority Average Waiting Time": priority_avg_waiting_time
    })
    
    return results

strategies = {
    #"auto?",
    "allow-priority?",
    #"adaptive-density?",
    #"adaptive-waiting-time?",
    #"priority-score?",
    #"multi-agent?"
}

# Iterate through epochs
results=[]

for strat in strategies:
    temp_results=None
    print(f"Running model for strategy: {strat}")
    for yellow_length in yellow_lengths:
        
        if strat == "auto?" or strat == "allow-priority?":
            for green_length in green_lengths:
                print("Green Length: ", green_length, " Yellow Length: ", yellow_length)
                temp_results=run_model(strat, yellow_length, green_length)
                results.extend(temp_results)    
        elif strat == "priority-score?":
            for weights in valid_weight_combinations:
                print("Yellow lenght:",yellow_length,"Neighbors: ", " Weights: ", weights)
                temp_results=run_model(strat, yellow_length, None,None, weights)
                results.extend(temp_results)
        elif strat == "multi-agent?":
            for neighbors in neighbors_asked:
                for weights in valid_weight_combinations:
                    print("Yellow lenght:",yellow_length,"Neighbors: ", neighbors, " Weights: ", weights)
                    temp_results=run_model(strat, yellow_length, None,neighbors, weights)
                    results.extend(temp_results)
        else:
            print("Yellow lenght:",yellow_length)
            temp_results=run_model(strat, yellow_length, None)
            results.extend(temp_results)
            
# Convert results to DataFrame and save
results_df = pd.DataFrame(results)
results_df.to_csv("traffic_model_results.csv", index=False)

# Kill NetLogo workspace
netlogo.kill_workspace()
