
import HTTP
import JSON
using Plots
using Dates
using DataFrames
using Pkg
using PyCall



agsi_dict = Dict()
open("$(@__DIR__)/agsi_links.json", "r") do f
        global agsi_dict
        dict_text = read(f, String)
        agsi_dict = JSON.parse(dict_text)
end
#return : code_data_array
function agsi_code(code)

        if !in(collect(keys(agsi_dict))).(code)
                println("Zły kod kraju \n Wybierz jeden z listy: \n $(join(collect(keys(agsi_dict)), ','))")
                return
        end
        println("Pobieram dane dla $(code) z agsi.gie.eu, w zaleznosci od CPU moze zajac kilka minut.")
        code_data_array = []
        links_no = size(agsi_dict[code], 1)
        i_link = 1
        error_response_counter = 0
        while i_link <= links_no
                link = agsi_dict[code][i_link]
                response_array = Dict()
                try
                        response = HTTP.request("GET", link, headers = Dict("x-key" => "709a7d013e4fda8f3e21166c33a1a691"))
                        if response.status == 200
                                 # println(response.status)
                                 response_body = String(response.body)
                                 one_link_data = JSON.parse(response_body)
                                 one_link_data = map(x -> [x["gasDayStartedOn"], x["gasInStorage"], x["workingGasVolume"]], one_link_data)
                                 push!(code_data_array, one_link_data)
                                 i_link += 1
                         end
                catch err_no
                        error_response_counter += 1
                        println("$(error_response_counter)/5 error(s)")
                        sleep(1)
                        if error_response_counter == 5
                                println("\n\nagsi unavailable / internet connection error \n\n  Errors:")
                                println("Return nothing on 5th error")
                                return
                        end
                end
                println("$(round(100 * (i_link - 1)/links_no))%")
        end
        return code_data_array
end
#return results in dataframe for country code
function calculation_array(code, agsi_data_array = agsi_code(code))
        println("Dane pobrane pomyślnie, trwa kalkulacja")
        df = DataFrames.DataFrame()
        for arr_element in agsi_data_array
                temp_df = DataFrames.DataFrame((; a, b, c) for (a, b, c) in arr_element)
                temp_df = temp_df[(temp_df.b .!= "-"), :]
                temp_df = temp_df[temp_df.c .!= "-", :]
                temp_df.b = parse.(Float64, temp_df.b)
                temp_df.c = parse.(Float64, temp_df.c)
                df = append!(df, temp_df)
        end
        df_grouped = groupby(df, :a)
        df_sumed = combine(df_grouped, [:b => sum, :c => sum])
        df_sumed.percentage = df_sumed.b_sum ./ df_sumed.c_sum
        return df_sumed
end

code_keys = sort(collect(keys(agsi_dict)))

#some fun
#last data
function see_last_data()
        global code_keys
        last_storage_results = Dict()
        for key in code_keys
                last_storage_results[key] = " : $(round(100 * convert(Array, calculation_array(key)[1:1, :])[4], digits = 3))%"
        end

        for key in code_keys
                println("$(key)$(last_storage_results[key])")
        end
end
function draw_one(code)
        global code_keys
        df = calculation_array(code)
        df.percentage .*= 100
        x_data = map(x -> Date(x), Matrix(df[:, 1:1]))
        y_data_percentage = Matrix(df[:, 4:4])
        plot(x_data, y_data_percentage, label = "", lw = 2, title = "$(code) : % gas storage / AGSI data ", yticks = [20, 40, 60, 80, 100])
        savefig("$(@__DIR__)/plot.png")
        println("done")
end

# compare 2  codes from array
function draw_storage_compare(code1, code2)
        global code_keys
        if !in(code_keys).(code1) || !in(code_keys).(code2)
                println("Nie poprawny kod(y), jako argument podaj dwa z ponizszych")
                println(join(code_keys, ","))
                return
        end

        df = calculation_array(code1)
        df.percentage .*= 100
        x_data = map(x -> Date(x), Matrix(df[:, 1:1]))
        y_data_percentage = Matrix(df[:, 4:4])
        df1 = calculation_array(code2)
        df1.percentage .*= 100

        x_data1 = map(x -> Date(x), Matrix(df1[:, 1:1]))
        y_data_percentage1 = Matrix(df1[:, 4:4])
        plot(x_data, y_data_percentage, label = code1, lw = 2, title = "% gas storage / AGSI data ", yticks = [20, 40, 60, 80, 100])
        plot!(x_data1, y_data_percentage1, label = code2, lw = 1)
end


using Gtk
using ImageView, TestImages
using Plots

function make_gui()
        my_app = GtkWindow("AGSI data storage by @ptrend", 200, 200)
        set_gtk_property!(my_app, :resizable, false)

        g = GtkGrid()
        set_gtk_property!(g, :column_homogeneous, true)
        set_gtk_property!(g, :column_spacing, 5)

        g[1,2] = "  "

        function x(button)

        end
        function on_button_clicked(button)
                my_plot_window = GtkWindow("", 610, 410)
                set_gtk_property!(my_plot_window, :resizable, true)
                draw_one(get_gtk_property(button, :label, String))
                img = GtkImage("$(@__DIR__)/plot.png")
                push!(my_plot_window, img)
                showall(my_plot_window)
        end
        j = 1
        jj = 4
        i = 1
        buttons_arr = []
                for (ind, code) in enumerate(sort(collect(keys(agsi_dict))))
                        j = Int(floor(jj / 4))
                        push!(buttons_arr, GtkButton(code))
                        g[i, j] = buttons_arr[ind]
                        set_gtk_property!(buttons_arr[ind], :margin_top, 10)
                        signal_connect(on_button_clicked, buttons_arr[ind], "clicked")
                        if i == 1
                                set_gtk_property!(buttons_arr[ind], :margin_left, 10)
                        end
                        jj += 1
                        i += 1
                        if i == 5
                                i = 1
                                set_gtk_property!(buttons_arr[ind], :margin_right, 10)
                        end
                        if j == 5
                                set_gtk_property!(buttons_arr[ind], :margin_bottom, 10)
                        end
                end
        push!(my_app, g)
        showall(my_app)
end

make_gui()
