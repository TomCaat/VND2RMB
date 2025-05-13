from kivy.app import App
from kivy.lang import Builder
from kivy.properties import StringProperty, NumericProperty
from kivy.clock import Clock
import requests

class VNDConverterApp(App):
    rate_text = StringProperty("汇率获取中...")
    result_text = StringProperty("")
    current_rate = NumericProperty(0)

    def build(self):
        Builder.load_file("ui.kv")
        Clock.schedule_once(lambda dt: self.get_rate(), 0.5)
        return self

    def get_rate(self):
        """获取实时汇率"""
        try:
            res = requests.get("https://api.exchangerate.host/latest?base=VND&symbols=CNY", timeout=5)
            self.current_rate = res.json()["rates"]["CNY"]
            self.rate_text = f"当前汇率：1 VND = {self.current_rate:.6f} CNY"
        except Exception as e:
            self.rate_text = f"汇率获取失败：{e}"

    def convert(self):
        """将用户输入的 VND 金额转换成人民币"""
        try:
            vnd_value = self.root.ids.vnd_input.text
            vnd = int(vnd_value)
            cny = round(vnd * self.current_rate, 2)
            self.result_text = f"≈ 人民币：¥{cny}"
        except:
            self.result_text = "输入错误"

    def multiply_input(self, multiplier):
        """快捷倍数按钮"""
        text = self.root.ids.vnd_input.text or "0"
        try:
            value = int(text)
        except:
            value = 0
        self.root.ids.vnd_input.text = str(value * multiplier)

    def clear_input(self):
        self.root.ids.vnd_input.text = ""
        self.result_text = ""
